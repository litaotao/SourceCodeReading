## ***Mar.3rd.2015***

- java基础
- maven基础，pom文件语法
- zeppelin-server/src/main/java/com/nflabs/zeppelin/socket/NotebookServer.java

## ***Mar.4th.2015***

- bin/*.sh流程，启动zeppelin服务的流程；
- 开始读ZeppelinServer.java，这是zeppelin web主服务的进程了；

## ***Mar.6th.2015***

- 完成 bin/*.sh，了解zeppelin服务启动流程，整理启动流程；
    + 启动流程：
        * 执行common.sh：定义zeppelin相关环境变量和执行参数
        * 执行functions.sh：定义相关函数
        * 规划zeppelin启动后相关文件路径：LOG,PID,CONFIG等，定义zeppelin webserver位置
        * start主函数：判断zeppelin服务是否在运行
        * start主函数：按需创建相关文件夹
        * start主函数：启动zeppelin服务
        * start主函数：执行函数wait_zeppelin_is_up_for_ci？？？
        * start主函数：判断zeppelin进程是否正常
- 开始读ZeppelinServer.java，这是zeppelin web主服务的进程了；