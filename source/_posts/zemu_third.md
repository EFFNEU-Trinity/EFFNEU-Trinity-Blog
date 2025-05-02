---
title: Rust的并发
date: 2025-05-02 20:22:00
author: zemu
tags:
  - zemu
  - Rust
  - 并发
  - 线程
---
1. 数据竞争和竞态条件

线程问题的核心原因就是操作系统调度器决定哪个线程获得下一个时间片

而对于应用程序员来说，这个顺序通常是**不可预测**且**无法精确控制**的

两个典型的线程问题

可以简单理解为：数据竞争是一种明确定义的、发生在内存访问层面的错误，它几乎总是会导致问题

竞态条件是更广泛的、发生在程序逻辑层面的问题，描述了结果依赖于时序的现象，而数据竞争是导致这种现象的一种（非常常见的）具体机制

避免数据竞争是编写正确并发程序的基础，但这还不足以完全避免所有竞态条件

**竞态条件**

当这种顺序不是程序员所期望或控制的时，就会导致非预期的、错误的行为

它关心的是一系列操作的最终结果是否因为并发执行顺序问题而出错

**数据竞争**

**两者的关系:**

**总结:**

* **数据竞争**关注的是底层的、对**同一内存位置**的**无同步冲突访问**（特别是涉及写操作）

它是关于内存操作本身的安全性

* **竞态条件**关注的是更高层的、程序**结果对执行时序的依赖性**

它是关于程序逻辑在并发环境下的正确性





2. 线程

在$$OS$$中，已执行程序的代码在一个**进程**中运行，操作系统则会负责管理多个进程

而进程可以包含多个并发执行的**线程**，而且同一个进程内的所有线程共享相同的内存空间

标准库采用$$  1:1  $$**模型**，即每个$$  Rust  $$线程对应一个操作系统$$（OS）$$线程



多线程优点可以加快程序速度，缺点则是

* 竞态条件，多个线程同时访问数据或资源

* 死锁，两个线程相互等待对方，这会阻止两者继续运行

* 只会发生在特定情况且难以稳定重现和修复的$$ bug$$



* 创建线程$$thread::spawn()$$

接受一个**闭包**

从程序员的角度来看，一旦$$  spawn  $$返回，你就应该认为新线程**已经在运行或随时可能开始运行了**

```rust
use std::thread;
use std::time::Duration;

fn main() {
    thread::spawn(|| {
        for i in 1..10 {
            println!("hi number {i} from the spawned thread!");
            thread::sleep(Duration::from_millis(1));
        }
    });

    for i in 1..5 {
        println!("hi number {i} from the main thread!");
        thread::sleep(Duration::from_millis(1));
    }
}
```

如果$$  Rust  $$程序的主线程执行完毕并退出，整个**进程**就会终止

操作系统会清理所有相关资源，包括该进程派生出的**所有子线程**，无论它们是否完成了工作

这就是为什么派生的线程经常会提前被砍掉

比如这个例子我们副线程通常只能循环到$$4$$或者$$5$$



* **等待线程**$$ JoinHandle, join()$$

为了让主线程在所有子线程都执行完毕后再终止，我们需要阻塞主线程

$$thread::spawn ()$$不仅仅是启动线程，它还会**返回**一个$$ JoinHandle$$

$$ JoinHandle$$是一个**拥有线程所有权的值，**&#x53EF;以看作是到那个子线程本身的代表

$$JoinHandle $$使子线程处于“可汇合$$ (joinable)$$”状态

丢弃$$  JoinHandle  $$使其进入“分离$$ (detached)$$”状态，父线程放弃了对其结束的等待和结果的获取

关键在于，你的主程序逻辑不再与这个线程的结束同步



通过对返回的$$JoinHandle$$调用$$join()$$方法，可以阻塞当前线程，直到$$JoinHandle$$对应线程执行完毕并返回

将$$  join  $$放置于何处这样的小细节，会影响线程是否同时运行

```rust
use std::thread;
use std::time::Duration;

fn main() {
    let handle = thread::spawn(|| {
        for i in 1..10 {
            println!("hi number {i} from the spawned thread!");
            thread::sleep(Duration::from_millis(1));
        }
    });
    //handle.join().expect("吓我一跳释放忍术");
    /**
    hi number 1 from the spawned thread!
    hi number 2 from the spawned thread!
    hi number 3 from the spawned thread!
    hi number 4 from the spawned thread!
    hi number 5 from the spawned thread!
    hi number 6 from the spawned thread!
    hi number 7 from the spawned thread!
    hi number 8 from the spawned thread!
    hi number 9 from the spawned thread!
    hi number 1 from the main thread!
    hi number 2 from the main thread!
    hi number 3 from the main thread!
    hi number 4 from the main thread!

    */
    for i in 1..5 {
        println!("hi number {i} from the main thread!");
        thread::sleep(Duration::from_millis(1));
    }

    //handle.join().expect("吓我一跳释放忍术");
    /**
    hi number 1 from the main thread!
    hi number 1 from the spawned thread!
    hi number 2 from the main thread!
    hi number 2 from the spawned thread!
    hi number 3 from the main thread!
    hi number 3 from the spawned thread!
    hi number 4 from the spawned thread!
    hi number 4 from the main thread!
    hi number 5 from the spawned thread!
    hi number 6 from the spawned thread!
    hi number 7 from the spawned thread!
    hi number 8 from the spawned thread!
    hi number 9 from the spawned thread!
    */
}
```



* $$move$$闭包

因为闭包默认获取外部环境值的引用

但是由于线程可以并行执行，我们没有办法确定引用所指向的外部的值什么时候消亡

也就没有办法遵循$$Rust$$的生命周期规范，无法通过编译

```rust
use std::thread;

fn main() {
    let v = vec![1, 2, 3];

    let handle = thread::spawn(|| {
        println!("Here's a vector: {v:?}");
    });

    drop(v); // oh no!

    handle.join().unwrap();
}


```

所以我们需要使用$$move$$关键字直接获取外部值的所有权

```rust
use std::thread;

fn main() {
    let v = vec![1, 2, 3];

    let handle = thread::spawn(move || {
        println!("Here's a vector: {v:?}");
    });

    handle.join().unwrap();
}
```



* 线程休眠$$thread::sleep()$$

操作系统会将该线程置于**阻塞**或**等待**状态

$$thread::sleep() $$接受一个$$  std::time::Duration  $$类型的参数，用来精确指定需要睡眠的时间长度

实际睡眠时间通常会**大于或等于**指定的时间

操作系统只能保证在指定时间过去后才会唤醒线程，但具体的唤醒时机还受调度策略和系统负载的影响

$$thread::sleep(Duration::from\_millis(500));$$

$$thread::sleep(Duration::from\_secs(2));$$



* &#x20;**消息传递**$$mpsc::channel()$$

不要通过共享内存来通讯，而是通过通讯来共享内存

> 共享内存是在多处理器计算机系统中，多个$$CPU$$可以同时访问的一块大容量内存

为了实现消息传递并发，$$Rust $$标准库提供了一个**信道**实现

信道是一个通用编程概念，表示数据从一个线程发送到另一个线程

信道包含发送者和接收者

当发送者或接收者任一被丢弃时可以认为信道被**关闭**了



这里使用$$ mpsc::channel ()$$函数创建一个新的信道

$$mpsc $$是**多个生产者，单个消费者**$$（multiple~~ producer, single ~~consumer）$$的缩写

简而言之，$$Rust $$标准库实现信道的方式意味着

一个信道可以有多个产生值的**发送**端，但只能有一个消费这些值的**接收**端

```rust
use std::sync::mpsc;
use std::thread;

fn main() {
    let (tx, rx) = mpsc::channel();
    /**
    mpsc::channel函数返回一个元组
    第一个元素是发送者，而第二个元素是接收者
    由于历史原因，tx 和 rx 通常作为发送者（transmitter）和 接收者（receiver）的缩写
    所以这就是我们将用来绑定这两端变量的名字
    */
    thread::spawn(move || {
        let val = String::from("hi");
        tx.send(val).unwrap();
    });
    let received = rx.recv().unwrap();
    println!("Got: {received}");
}
}
```

$$send $$方法返回一个$$  Result<T, E>  $$类型

所以如果接收端已经被丢弃了，将没有发送值的目标，发送操作会返回错误

除此之外，$$send $$函数获取其参数的所有权并移动这个值归接收者所有

所以我们在将一个值发送之后就不应再继续使用它



信道的接收者有两个有用的方法：$$recv $$和$$ try\_recv$$

这里，我们使用了$$ recv$$

这个方法会阻塞当前线程执行直到从信道中接收**一个**值，注意只接受一个值，所以要接受多个值要循环使用

一旦发送了一个值，$$recv $$会在一个$$Result<T, E> $$中返回它

当信道发送端关闭，$$recv $$会返回一个错误表明不会再有新的值到来了

$$try\_recv $$不会阻塞，相反它立刻返回一个$$ Result<T, E>$$

$$Ok $$值包含可用的信息，而$$  Err  $$值代表此时没有任何消息

如果线程在等待消息过程中还有其他工作时使用$$  try\_recv  $$很有用

可以编写一个循环来频繁调用$$ try
\_recv$$，在有可用消息时进行处理，其余时候则处理一会其他工作直到再次检查





* 共享状态

消息传递是一个很好的处理并发的方式，但并不是唯一一个

另一种方式是让多个线程访问同一块内存中的数据，也就是**共享状态**

在某种程度上，信道都类似于单所有权，因为一旦将一个值传送到信道中，将无法再使用这个值

共享内存类似于多所有权，多个线程可以同时访问相同的内存位置





* 使用$$  Sync  $$和$$  Send ~~trait  $$的可扩展并发

  通常并不需要手动实现$$  Send  $$和$$ Sync ~~trait$$

  因为由$$  Send  $$和$$  Sync  $$的类型组成的类型，自动就是$$  Send  $$和$$  Sync  $$的

  因为它们是标记$$ trait$$，不需要实现任何方法，它们只是用来加强并发相关的不可变性的

  手动实现这些标记$$  trait  $$涉及到编写不安全的$$  Rust  $$代码

  * $$Send ~~Trait$$表明实现该$$Trait$$类型的所有权可以在线程间传送

  几乎所有的$$  Rust  $$类型都是$$Send $$的，任何完全由$$  Send  $$的类型组成的类型也会自动被标记为$$ Send$$

  除了$$Rc$$和裸指针

  * $$Sync ~~trait $$表明一个实现了$$  Sync  $$的类型可以安全的在多个线程中拥有其值的引用

  换一种方式来说，对于任意类型$$ T$$，如果$$ \&T$$是$$  Send  $$的话$$  T  $$就是$$  Sync  $$的

  这意味着其引用就可以安全的发送到另一个线程

  完全由$$  Sync  $$的类型组成的类型也是$$  Sync  $$的

  除了$$Rc$$和裸指针



* 一个典型的死锁

```rust
use std::thread::{self, sleep};
use std::sync::{Arc , Mutex};
use std::time::Duration;
fn main(){
    let mutex1 = Arc::new(Mutex::new(0));
    let mutex2 = Arc::new(Mutex::new(0));

    let mutex1_clone1 = Arc::clone(&mutex1);
    let mutex2_clone1 = Arc::clone(&mutex2);

    let mutex1_clone2 = Arc::clone(&mutex1);
    let mutex2_clone2 = Arc::clone(&mutex2);

    let handle1 = thread::spawn(move ||{
        println!("线程1正在尝试锁定互斥器1...");
        let _lock1 = mutex1_clone1.lock().unwrap();
        println!("线程1已成功锁定互斥器1");
        sleep(Duration::from_secs(1));
        println!("线程1正在尝试锁定互斥器2...");
        let _lock2 = mutex2_clone1.lock().unwrap();
        println!("线程1已成功锁定互斥器2(如果执行到这里,说明未死锁)");
    });
    let handle2 = thread::spawn(move ||{
        println!("线程2正在尝试锁定互斥器2...");
        let _lock1 = mutex2_clone2.lock().unwrap();
        println!("线程2已成功锁定互斥器2");
        sleep(Duration::from_secs(1));
        println!("线程2正在尝试锁定互斥器1...");
        let _lock2 = mutex1_clone2.lock().unwrap();
        println!("线程2已成功锁定互斥器1(如果执行到这里,说明未死锁)");
    });
    println!("正在等待子线程执行完毕呢");
    handle1.join().unwrap();
    handle2.join().unwrap();
    println!("未发现死锁呢");
}
```