---
title: cpp智能指针讨论
---

### 智能指针

智能指针秉承 RAII 的思想，所以管理的资源应是**获取即初始化**的，动态管理的资源（即 new 在堆上的资源）。

#### 优先使用 make 系列函数而非 new 来创建智能指针

make 系列有三个函数：make_shared(),make_unique(),allocate_shared()。

allocate_shared()的第一个实参为动态分配内存的分配器对象。

使用 make 系列函数可以避免冗余代码，且保证内存安全：

但在需要自定义删除器的时候，应该使用构造函数（make 函数不允许传入自定义删除器）。

```
void func() {
    // 直接使用 new 和 shared_ptr 构造函数
    std::shared_ptr<MyClass> sp(new MyClass);
    // 其他可能抛出异常的代码...
}

如果在sp构造完毕之前，MyClass内存分配完毕之后（二者的发生顺序由编译器控制，中间可能执行其他代码）发生了异常，就会导致MyClass新对象的内存无法被释放，造成内存泄漏。

void func() {
    // 使用 make_shared
    auto sp = std::make_shared<MyClass>();
    // 其他可能抛出异常的代码...
}

make_shared()将对象创建和控制块分配绑定，二者会一次性完成，从而有效地保证了内存的安全。

make_unique()等同理。

从内存空间的角度来看，前者会将对象的内存和控制块的内存分配到不同地址，进行了两次分配，效率较低。
而后者则将对象和控制块分配到一块连续的内存上，提升了效率。

需要注意，析构时，如果控制块对应的内存不析构，连续分配的对象内存也无法析构。（在引用计数为0而弱计数不为0时会发生）
```

#### std::unique_ptr：独占所有权

std::unique_ptr 删除了拷贝构造函数和拷贝赋值运算符（= delete），不允许通过这些方式来转移数据的所有权。

而应该使用 `std::move` 。

##### 创建对象指针或数组指针

```cpp
auto p1 = std::make_unique<int>(42);
//不提供[]运算符

auto p2 = std::make_unique<int[]>(5); //（只允许给出一个参数表示容器大小）
//不提供*或->运算符
//不推荐使用
```

##### 跨指针类型转换

支持从 unique_ptr 到 shared_ptr 的隐式转换，反之则不支持。

除非手动将引用计数为 1 的 shared_ptr 的资源转移给 unique_ptr。

```cpp
std::unique_ptr<int> u = std::make_unique<int>(42);
std::shared_ptr<int> s = std::move(u);  // 所有权转移
// 此时 u == nullptr

std::shared_ptr<int> s = std::make_shared<int>(42);
// std::unique_ptr<int> u = s;  // 编译错误
// 唯一方式：如果引用计数为1
if(s.use_count() == 1) {
    std::unique_ptr<int> u(s.get());
    s.reset();  // 必须手动释放所有权
}
```

##### 删除器

与 shared_ptr 相比，unique_ptr 的删除器本身作为指针对象的一部分，在使用构造函数传入删除器函数时，应该在模板参数中也声明删除器的类型。

```cpp
auto up_del1 = [](int * p){
        delete p;
        cout << "up1 deleted." << endl;
    };

unique_ptr<int, decltype(up_del1)> up1(new int(42), up_del1);

```

unique_ptr 通过删除器以工厂模式对指针所指内容进行析构，支持复杂的资源管理，使所有析构操作由智能指针自动完成。

#### std::shared_ptr：分享所有权

可以有多个指针共享一个数据，每创建一个指针，引用计数加一，每析构一个指针，引用计数减一。

shared_ptr 的大小是裸指针的两倍，这是由于 shared_ptr 既包含了一个指向资源的裸指针，也包含了一个指向引用计数所在控制块的裸指针。

引用计数的递增或递减必须是原子操作，读写效率比较低。

与复制语义相比，移动语义对 shared_ptr 更有效率，因为引用计数不会发生变化。

##### shared_ptr 初始化与内存

如果使用 make_shared()对 shared_ptr 进行初始化，就不能自定义删除器，编译器会将对象和控制块绑定到连续的内存上。

要使用自定义的删除器，应该使用 shared_ptr()的构造函数：

```
// 示例：管理文件指针
void file_deleter(FILE* f) {
    if (f) fclose(f);
}

int main() {
    FILE* raw_fp = fopen("data.txt", "r");
    //auto sp_fp = make_shared(raw_fp);
    std::shared_ptr<FILE> sp_fp(raw_fp, file_deleter); //使用构造函数传递自定义删除器
}
```

##### enable_shared_from_this

enable_shared_from_this 是一个辅助 shared_ptr 使用的**基类模板**。

使 this 裸指针能够安全地转换为 shared_ptr，避免以下危险操作：

```
class BadExample {
public:
    std::shared_ptr<BadExample> get_shared() {
        return std::shared_ptr<BadExample>(this); // 导致多个控制块
    }
};

class GoodExample : public std::enable_shared_from_this<GoodExample> {
public:
    void process() {
        //前提：已经有shared_ptr控制有效的控制块
        auto self = shared_from_this(); // 使用指定函数安全获取
        // 传递到异步回调等场景
    }
};
```

##### 控制块

与 unique_ptr 将删除器连续存储在指针对象中不同，shared_ptr 的删除器会存储在控制块中。

![](/Asset/image.png)

std::make_shared()总是创建一个控制块。

从 unique_ptr 向 shared_ptr 转换总是会创建一个控制块。

shared_ptr 的构造函数调用裸指针时，总是创建一个控制块。

控制块附属于对象指针，所以使用同一裸指针多次构造 shared_ptr 会导致多重控制块，**多重的控制块意味着多重的引用计数**，将引发重复析构等问题。

不允许也不应该使用 shared_ptr 指向数组。

（图中的弱计数指的就是 weak_ptr 的引用计数）。

#### std::weak_ptr

std::weak_ptr 指向 shared_ptr 管理的对象，但不会增加引用计数。

可以从 shared_ptr 初始化一个 weak_ptr。

使用.lock()将其转换为 shared_ptr 则可以临时访问对象。

用于**仅检测指针是否空悬**，或**类间循环引用**的问题。

无法解引用来获取 weak_ptr 中的内容，使用者只能通过.expired()观测到 weak_ptr 是否还指向有效内容。

如果想要获取，就使用.lock()。

weak_ptr 的大小与 shared_ptr 完全一致，它不会影响 shared_ptr 的引用计数，但拥有控制块中的另一个引用计数（即弱计数）。