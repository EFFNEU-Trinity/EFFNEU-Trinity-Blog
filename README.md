# EFFNEU-Trinity 博客
本博客将作为颜✌、洪✌、宸✌的学习记录分享

友情链接：
- 颜✌的个人博客：[ZIYAN137.github.io](ZIYAN137.github.io)
- 洪✌的个人博客：[mildred522.github.io](mildred522.github.io)
- 宸✌他没有博客。

采用Hexo生成静态博客并且 CI/CD 到 [EFFNEU-Trinity.github.io](https://effneu-trinity.github.io/#/)

# 首次使用

## 安装git

直接输入命令
```bash
sudo apt-get install git
```
安装后使用
```bash
git --version
```
查看当前版本

## 安装NodeJS
Hexo是基于NodeJS编写的, 所以需要安装一下NodeJS和里面的npm工具。
```bash
sudo apt-get install nodejs
sudo apt-get install npm
```
之后使用
```bash
node -v
npm -v
```
查看当前版本

## 安装Hexo

前面git和nodejs安装好后, 就可以安装hexo了
```bash
npm install -g hexo-cli
```
之后使用
```bash
hexo -v
```
查看当前版本

此后安装以下插件，安装依赖
```bash
npm install hexo-deployer-git --save
npm install hexo-hide-posts --save
npm install
```
# 如何编写博客
此处以我要新写一篇 `title` 为例

首先创建并签出到 `new/title` 分支

通过 `./new_blog.sh title` 创建新的博客。

在 `source/_post/title.md` 中编写你的博客

> 注意：请在tag中打上自己的ID来标识作者。

```markdown
tag:
- author:ZIYAN137
- C++
```

在 `source/Asset/title` 中存放图片等资源

提交后并入到 `master` 分支

如果想要修改，则从主分支上创建并签出 `fix/title` 分支即可

具体提交规范详见 [conventionalcommits](https://www.conventionalcommits.org/en/v1.0.0/)
