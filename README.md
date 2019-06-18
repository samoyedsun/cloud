作者信息
---
- 作者:LGC
- 时间:2017年 3月 4日 星期六 10时44分20秒 

- 作者:MRZ
- 时间:2019年 6月18日 星期二 17时28分40秒

学习资料
---
|标题|网址|
|-|-|
|服务端框架skynet|https://github.com/cloudwu/skynet/wiki|
|skynet学习资源|http://skynetclub.github.io/skynet/resource.html|
|云风的演讲视频|http://gad.qq.com/content/coursedetail?id=467|
|云风的blog|https://blog.codingnow.com/|

本框架解决了以下问题
---
- 服务器热更新
- log4日志服务功能
- web服务功能
- 服务注册与发现功能
- 基于http协议，消息序列化和反序列化基于json的rpc功能
- mysql和redis代理功能
- websocket

集成库
---
- cjson
- [dpull的webclient](https://github.com/dpull/lua-webclient)
- lfs
- websocket

目录说明
---
```txt
├── bin                     启动脚本
├── cservice                skynet cservice
├── doc                     文档
├── etc                     skynet进程启动配置文件
├── examples            
├── logs                    日志目录
├── luaclib                 lua c语言模块
├── lualib                  lua模块代码
├── lualib-src              lua c语言模块代码
├── run                     进程运行时存放文件目录，比如说进程pid
├── service                 skynet服务目录
├── service-src             skynet c语言服务代码
├── skynet                  skynet
└── test                    测试目录
```

编译前安装依赖库:
- ubuntu
    ```sh
    sudo apt-get install libcurl4-gnutls-dev libreadline-dev autoconf
    ```
- centos
    ```sh
    sudo yum install libcurl-devel readline-devel autoconf
    ```

编译:
- Linux
    ```sh
    make linux
    ```
- Mac
    ```sh
    make macosx
    ```
启动命令：
```sh
./bin/start.sh
```

后台运行，选择test环境启动
```sh
./bin/start.sh -v test -D
```

热更新命令：
```sh
./bin/start.sh -U
```

常见问答A&Q：
- MAC下编译如果遇到的问题:
    - 以下报错
        ```txt
        ld: library not found for -lgcc_s.10.4
        ```
    - 需要做以下操作解决
        ```sh
        cd /usr/local/lib && sudo ln -s ../../lib/libSystem.B.dylib libgcc_s.10.4.dylib
        ```
    - 解决方法来自[这里](http://bugsfixes.blogspot.com/2016/02/mac-ld-library-not-found-for-lgccs104.html)
- 怎样跨节点rpc调用?
    - 参照doc/node_rpc_gate.txt相关文档和代码
- 怎样添加一个客户端网络长链接请求？
- 怎样添加一个客户端短链接请求处理？
- 怎样给长链接推送消息？