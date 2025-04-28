---
title: Rust中Slice类型的详解
date: 2025-04-28 20:18:12
author: zemu
tags:
  - zemu
  - Rust
  - Slice
---

# Slice 概念

Slice 允许你引用集合中的一部分连续的元素序列，而不需要拥有这些元素的所有权。
Slice 的长度（包含多少个元素）是在运行时确定的，而不是在编译时。
因此，**Slice 类型本身**（如 [T] 或 str）是 **动态大小类型 (Dynamically Sized Type, DST)**。
它本身不拥有数据，只是单纯地指某块连续内存。
我们不能直接创建 DST 类型的变量，只能通过其**引用**（如 &[T] 或 &str）来使用它们。

常用对 slice 的引用有两种：

## &[T] 切片引用

这是对类型 T 的数组或 Vec<T>（或实现了 Deref<Target=[T]> 的其他类型）的一部分的引用。
&[T] 在内部实际上是一个 **胖指针 (fat pointer)**，包含两个信息：

*   一个指向 Slice 第一个元素的指针
*   Slice 的长度，即它包含多少个元素

```rust
// 示例：从数组创建切片
let arr: [i32; 5] = [1, 2, 3, 4, 5];

let slice_all: &[i32] = &arr;         // 引用整个数组 [1, 2, 3, 4, 5]
let slice_all_explicit: &[i32] = &arr[..]; // 显式引用整个数组，效果同上

// 使用 range 语法创建部分元素的切片
// range a..b 包含索引 a，但不包含索引 b
let slice_part: &[i32] = &arr[1..4];   // 引用索引 1 到 3 (不包括 4) 的元素 [2, 3, 4]
let slice_from: &[i32] = &arr[2..];    // 引用索引 2 到末尾的元素 [3, 4, 5]
let slice_to: &[i32] = &arr[..3];     // 引用从开头到索引 2 (不包括 3) 的元素 [1, 2, 3]

println!("arr: {:?}", arr); // 使用标准引号 "
println!("slice_all: {:?}", slice_all);
println!("slice_part: {:?}", slice_part);
println!("slice_from: {:?}", slice_from);
println!("slice_to: {:?}", slice_to);

// 示例：从 Vec 创建切片
let vec: Vec<i32> = vec![10, 20, 30, 40]; // 修正：明确 Vec 类型
let slice_vec: &[i32] = &vec[..];        // 引用整个 Vec 的数据部分 [10, 20, 30, 40]
let slice_vec_part: &[i32] = &vec[1..3]; // 引用 Vec 中索引 1 到 2 的元素 [20, 30]

println!("vec: {:?}", vec);
println!("slice_vec: {:?}", slice_vec);
println!("slice_vec_part: {:?}", slice_vec_part);

// 示例：可变切片引用
let mut arr_mut = [1, 2, 3];
let mut_slice: &mut [i32] = &mut arr_mut[1..]; // 获取对索引 1 及之后元素的可变引用 [2, 3]

// 可以通过可变切片修改原数组或 Vec 的数据
mut_slice[0] = 99; // 修改切片中的第一个元素（对应原数组索引 1 的元素）
// mut_slice[1] = 100; // 修改切片中的第二个元素（对应原数组索引 2 的元素）

println!("Original arr_mut after modification: {:?}", arr_mut); // 输出：Original arr_mut after modification: [1, 99, 3]
```

**注意：** &[T] 和 &[T;N] 是两回事。
&[T; N] 是单个指针，&[T] 是胖指针（指针 + 长度）。
如果我们直接获取某数组的一个引用，则是 &[T;N] 类型的，编译时可以确定长度。
当然你也可以把类型写成 &[T] ，这属于数组引用隐式转换为切片引用（&[T]）。
因为固定大小总是可以被视为一个动态大小，编译器可以轻松地构造出 (指针, 长度 N) 这个胖指针。
而对 slice 的引用则是 &[T] ，不能写成 &[T;N] ，因为 slice 是一个 DST 类型。
其长度在编译期不能确定，其引用不能隐式转回长度在编译期可以确定的数组引用。
如果你想强转回去，可以使用 try_into() 方法。
这个方法会在运行时检查切片的长度。如果长度正好是 N，它会返回 Ok(&[T; N])；否则返回 Err。

## &str 字符串切片

str 是 Rust 的原生字符串类型，代表一个有效的 UTF-8 字节序列，但它本身也是一个 DST。
因此，我们几乎总是通过它的引用形式 &str 来使用它。
&str 通常就被称为**字符串切片**。

与 &[T] 类似，&str 在内部也是一个胖指针，包含：

*   一个指向构成字符串的 UTF-8 字节序列的第一个字节的指针
*   字符串切片的**字节长度**

**重要特性与约束:**

*   Rust 的 String 和 &str 都保证其内容始终是有效的 UTF-8 编码。
*   对 String 或 &str 进行切片操作时，索引是基于**字节**的。
*   必须确保切片的起始和结束边界都落在有效的 UTF-8 **字符边界**上。
如果在某个字符的多字节表示的中间进行切割，程序会在运行时 panic（崩溃）。

```rust
// 字符串字面量本身就是 &'static str 类型 (一个具有静态生命周期的字符串切片)
let s_literal: &'static str = "Hello, Rust!"; // 使用标准引号 " 和 '

// 从 String 创建字符串切片
let my_string: String = String::from("你好，世界"); // "你好，世界" 是 UTF-8 编码

// 引用整个 String 的数据
let slice_str_all: &str = &my_string;         // 隐式引用整个字符串
let slice_str_all_explicit: &str = &my_string[..]; // 显式引用整个字符串

// 引用部分 String 数据
// 注意：索引是基于 *字节* 的，并且必须落在字符边界上
// 在 UTF-8 中:
// '你' 占 3 字节 (0, 1, 2) // 使用标准单引号 '
// '好' 占 3 字节 (3, 4, 5)
// '，' 占 3 字节 (6, 7, 8)
// '世' 占 3 字节 (9, 10, 11)
// '界' 占 3 字节 (12, 13, 14)
// 总共 15 个字节

// 合法的切片：边界都在字符之间
let slice_part_str: &str = &my_string[0..6]; // 引用前两个字符 "你好" (字节 0 到 5)
println!("slice_part_str: {}", slice_part_str); // 输出：slice_part_str: 你好

let slice_from_str: &str = &my_string[9..]; // 引用从第 10 个字节（索引 9）开始到末尾 "世界"
println!("slice_from_str: {}", slice_from_str); // 输出：slice_from_str: 世界

let slice_to_str: &str = &my_string[..12]; // 引用从开头到第 12 个字节（不包括索引 12）"你好，世"
println!("slice_to_str: {}", slice_to_str); // 输出：slice_to_str: 你好，世

// 非法的切片：边界落在了字符内部，会导致 panic
// let invalid_slice = &my_string[0..1]; // 错误！字节 1 在 '你' 的中间
// let invalid_slice2 = &my_string[..8]; // 错误！字节 8 在 '，' 的中间

// Rust 提供方法检查边界是否合法
if my_string.is_char_boundary(1) {
    // 不会执行，因为 1 不是字符边界
    let _slice = &my_string[..1];
} else {
    println!("Index 1 is not a valid char boundary for '{}'", my_string); // 使用标准单引号 '
}

// 获取 &mut str (可变字符串切片) 比较少见，并且需要格外小心
// String 没有提供安全的、公开的获取 &mut str 的方法，因为任意修改字节可能破坏 UTF-8 有效性。
// 通常通过操作底层的 &mut [u8] (可变字节切片) 并确保结果是有效 UTF-8，
// 或者使用一些知道自己在做什么的 unsafe 代码（如 String::as_mut_str）。
let mut s = String::from("hello");
// let mut_str_slice: &mut str = s.as_mut_str(); // as_mut_str 是 unsafe 的
// 安全地修改 &mut str 的例子（如使用 &str 的方法）
{
    // 获取可变字节切片是安全的，但需要确保后续操作维持 UTF-8 有效性
    let mut_bytes: &mut [u8] = unsafe { s.as_bytes_mut() }; // 注意 unsafe
    // 在字节层面修改，但要保证结果仍是有效 UTF-8
    mut_bytes.make_ascii_uppercase(); // 这个方法保证了 ASCII 范围内的 UTF-8 有效性
}
println!("Modified string: {}", s); // 输出：Modified string: HELLO
```