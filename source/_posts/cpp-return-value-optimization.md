---
title: cpp-return-value-optimization
date: 2025-05-28 16:23:00
tags:
  - cpp
  - ZIYAN137
---

返回值优化是C++中的一种编译优化技术，它允许编译器将函数返回的对象直接构造到它们本来要存储的变量空间中而不产生临时对象。这样子可以减少复制构造和移动构造的次数，提升性能。

<!-- more -->

严格来说返回值优化分为RVO（Return Value Optimization）和 NRVO（Named Return Value Optimization），不过在优化方法上的区别并不大。前者是未命名的临时对象（纯右值），后者是具名的对象（泛左值）。

在C ++ 11标准中，这种优化技术被称为复制省略（copy elision）。如果使用GCC作为编译器，则这项优化技术是默认开启的，取消优化需要额外的编译参数 `-fno-elide-constructors` 。

## 示例

```c++
#include <iostream>

class X {
public:
    X() { 
        std::cout << "X ctor" << std::endl; 
    }
    
    X(const X &x) { 
        std::cout << "X copy ctor" << std::endl; 
    }
    
    ~X() { 
        std::cout << "X dtor" << std::endl; 
    }
};

X make_x() {
    X x1;
    return x1;
}

int main() {
    X x2 = make_x();
}
```

可以看到函数 `make_x()` 返回了对象 `x1` 并赋值到 `x2` 上，理论上说这其中必定需要经过两次复制构造函数，第一次是 `x1` 复制到临时对象，第二次是临时对象复制到 `x2` 。

加入编译参数 `-fno-elide-constructors` 后，用GCC编译并运行：

```c++
X ctor 
X copy ctor 
X dtor 
X copy ctor 
X dtor 
X dtor
```

会发现和我们的预期一致。

去掉编译参数后，用GCC编译并运行：

```plaintext
X ctor
X dtor
```

会发现，在RVO/NRVO的作用下，这段程序竟然一次复制构造都没有调用。减少了两次复制构造和析构。优化了性能。

## RVO的失效

由于RVO和NRVO是编译时优化，所以在编译期间无法确定的操作，编译器将不会进行RVO/NRVO优化。

示例：

```c++
#include <iostream>
#include <ctime>

class X {
public:
    X() { 
        std::cout << "X ctor" << std::endl; 
    }

    X(const X &x) { 
        std::cout << "X copy ctor" << std::endl; 
    }

    ~X() { 
        std::cout << "X dtor" << std::endl; 
    }
};

X make_x() {
    X x1, x2;

    if (std::time(nullptr) % 50 == 0) {
        return x1;
    } else {
        return x2;
    }
}

int main() {
    X x3 = make_x();
}
```

现在 `make_x()` 函数无法在编译时确定返回哪个对象，所以就会有以下输出：
`-fno-elide-constructors` 参数：

```plaintext
X ctor 
X ctor 
X copy ctor 
X dtor 
X dtor 
X copy ctor 
X dtor 
X dtor 
```

无参数：

```plaintext
X ctor 
X ctor 
X copy ctor 
X dtor 
X dtor 
X dtor 
```

这时只能省略一次复制构造。因为在示例代码中，到底是复制 `x1` 还是 `x2`，是无法在编译时确定的。因此编译器无法在默认构造阶段就对 `x3` 进行构造，它需要分别将x1和x2构造后，根据运行时的结果将 `x1` 或者 `x2` 复制构造到 `x3`。

有兴趣的可以去https://cppinsights.io/生成中间代码看看。



此外，不要滥用移动。不要`return std::move(local)` 。返回局部变量会隐式地移动它。 显式的 `std::move` 总是不良的实践，因为它会阻碍可以把移动完全消除掉的返回值优化（RVO）。

## RVO进化过程（C++11到C++20）

### C++11

虽然 RVO/NRVO 可以省略创建临时对象和复制构造的过程，但是 C++11 标准规定复制构造函数必须是存在且可访问的，否则程序不符合语法规则。（这条规则在C++17被移除）

```c++
#include <iostream>

class X {
public:
    X() {
        std::cout << "X ctor" << std::endl;
    }

    ~X() {
        std::cout << "X dtor" << std::endl;
    }

private:
    // 拷贝构造函数设为私有
    X(const X& x) {
        std::cout << "X copy ctor" << std::endl;
    }
};

X make_x() {
    return X(); // 返回一个临时对象
}

int main() {
    X x2 = make_x();
    return 0;
}
```

我们将类X的复制构造函数设置为私有。根据返回值优化的要求，复制构造函数必须是可访问的，所以上面的代码在 C++11的编译环境下将会导致编译错误。

C++11 加入了移动作为次优选，即使编译器没有执行 RVO/NRVO ，但是仍然可以通过移动而非拷贝来降低值返回的成本。

### C++14

C++14 标准对返回值优化做了进一步的规定，规定中明确了对于常量表达式和常量初始化而言，编译器应该保证RVO，但是禁止NRVO。

### C++17

新特性：强制拷贝省略（Guaranteed Copy Elision）

对于某些特定类型的表达式（主要是纯右值 prvalue），编译器必须省略拷贝和移动操作。

```c++
MyType x = MyType(); // MyType() 是 prvalue，x 直接在 MyType() 的位置构造

MyType func() {
    return MyType(); // MyType() 是 prvalue，直接在调用者提供的内存中构造
}
```

C++17 将拷贝省略作为语义而非优化，这使得程序员可以依赖这一行为。

例如，一个只有删除的拷贝/移动构造函数的类型，仍然可以通过这种方式从工厂函数返回。

```c++
class NonCopyableNonMovable {
public:
    NonCopyableNonMovable() { std::cout << "Constructed\n"; }
    ~NonCopyableNonMovable() { std::cout << "Destructed\n"; }
    NonCopyableNonMovable(const NonCopyableNonMovable&) = delete;
    NonCopyableNonMovable(NonCopyableNonMovable&&) = delete;
};

NonCopyableNonMovable factory() {
    return NonCopyableNonMovable(); // C++17 起，这是合法的，会发生强制拷贝省略
}

int main() {
    NonCopyableNonMovable obj = factory(); // 对象直接在 obj 的内存中构造
}
```

在 C++17 之前，`factory()` 的调用通常是不合法的，因为 `NonCopyableNonMovable` 不可拷贝也不可移动。



NRVO 仍然可选： 值得强调的是，强制拷贝省略主要适用于返回纯右值的情况。对于具名返回值优化 (NRVO)，即返回一个函数内的命名局部变量（`MyType obj; ... return obj;`），它仍然是可选的优化。这是因为 NRVO 的条件更复杂，例如函数可能有多个返回路径，返回不同的命名对象，或者对象的生命周期和构造方式使得直接在返回槽中构造更为困难。

### C++20

对于协程中的 `co_return` 语句，如果返回的是一个 prvalue，也适用强制拷贝省略的规则。如果 `co_return` 一个局部变量，其行为也旨在尽可能优化，类似于 NRVO 的目标。
