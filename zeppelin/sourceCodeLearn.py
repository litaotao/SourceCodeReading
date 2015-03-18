common.sh
'''
这个文件应该是定义一些zeppelin运行时环境变量和运行时参数。
FWDIR获取当前绝对路径，即common.sh文件的绝对路径。
'''

'''
find -L: Follow symbolic links，即在查找的时候也查找快捷方式。
'''

functions.sh

zeppelin-daemon.sh

'''
# 定义变量，变量名不用加美元符号$，使用一个定义过的变量时，只要在前面加上美元符号$即可；
  echo $PATH 等于 echo ${PATH}
  我想下面是定义变量BIN，只是不是简单地定义，而是使用语句给变量赋值，语句是dirname "${BASH_SOURCE-$0}"
  即BIN是语句dirname "${BASH_SOURCE-$0}"的执行结果。

# shell变量$#,$@,$0,$1,$2的含义解释
$$ 
Shell本身的PID（ProcessID） 
$! 
Shell最后运行的后台Process的PID 
$? 
最后运行的命令的结束代码（返回值） 
$- 
使用Set命令设定的Flag一览 
$* 
所有参数列表。如"$*"用「"」括起来的情况、以"$1 $2 … $n"的形式输出所有参数。 
$@ 
所有参数列表。如"$@"用「"」括起来的情况、以"$1" "$2" … "$n" 的形式输出所有参数。 
$# 
添加到Shell的参数个数 
$0 
Shell本身的文件名 
$1～$n 
添加到Shell的各参数值。$1是第1参数、$2是第2参数…。 

# 前面两行BIN是取得当前执行文件zeppelin-daemon.sh所在的目录
'''

'''
奇了个怪了，$hostname返回为空，$HOSTNAME正常返回ubuntu2，$(hostname)也能正常返回ubuntu2
'''

'''
shell中if语法详见：http://www.tektea.com/archives/2344.html
对文件属性的判断，完整请见http://vbird.dic.ksu.edu.tw/linux_basic/0340bashshell-scripts_3.php
1. -r file #用户可读为真
2. -w file #用户可写为真
3. -x file #用户可执行为真
4. -f file #文件存在且为正规文件为真
5. -d file #如果是存在目录为真
6. -c file #文件存在且为字符设备文件
7. -b file #文件存在且为块设备文件
8. -s file #文件大小为非0为真，可以判断文件是否为空
9. -e file #如果文件存在为真
10. -z : -z STRING      True if string is empty.
11. -n : -n STRING  the length of STRING is nonzero
12. -L ： 该『档名』是否存在且为一个连结档？
mkdir -p: -p, --parents     no error if existing, make parent directories as needed
'''

'''
local 简单地理解成局部变量吧。
kill 信号值：
  0： exit code indicates if a signal may be sent，向某一进程发送一个无效的信号，
      如果该进程存在（能够接收信号），echo $?为1，否则为0
  9： cannot be blocked
执行这个函数具体还不知道要干嘛
'''

'''
关键了，启动zeppelin的流程
// nohup: 让提交的命令忽略 hangup 信号
// ">>"则表示把输出追加到filename文件的末尾，如果文件不存在则创建它。
// 如果谈到I/O重定向，就涉及到文件标识符(File Descriptor)的概念, 在Linux系统中，系统为每一个打开的文件指定一个文件标识符以便系统对文件进行跟踪，
这里有些和C语言编程里的文件句柄相似，文件标识符是一个数字，不同数字代表不同的含义，默认情况下，系统占用了3个，分别是
0标准输入（stdin）,1标准输出(stdout), 2标准错误(stderr)，&表示标准输出和错误。
// 重新定义标准输入，输出，和错误的文件标识符
重新定义文件标识符可以用i>&j命令，表示把文件标识符i重新定向到j，你可以把"&"理解为"取地址"
#exec 5>&1
表示把文件标识符5定向到标准输出，这个命令通常用来临时保存标准输入。
这里的 2>&1 表示把标准错误也定向到标准输出
// nice — 调整程序运行的优先级，格式：nice [OPTION] [command [arguments...]]
优先级的范围为-20 ～ 19 等40个等级，其中数值越小优先级越高，数值越大优先级越低，既-20的优先级最高， 19的优先级最低。

nohup nice -n $ZEPPELIN_NICENESS $ZEPPELIN_RUNNER $JAVA_OPTS -cp $CLASSPATH $ZEPPELIN_MAIN >> "${ZEPPELIN_OUTFILE}" 2>&1 < /dev/null &
这条启动命令解读分以下部分：
1. nice -n $ZEPPELIN_NICENESS $ZEPPELIN_RUNNER $JAVA_OPTS -cp $CLASSPATH $ZEPPELIN_MAIN
启动zeppelin进程
2. nohup COMMAND >> "${ZEPPELIN_OUTFILE}" 2>&1 < /dev/null &
用nohup使zeppelin进程在后台可靠运行，并把启动的日志输出到 文件：ZEPPELIN_OUTFILE，输出信息包括标准输出和错误信息，并且在每次启动
时都先清空这个ZEPPELIN_OUTFILE文件内容。
-cp 是java启动参数：-cp <class search path of directories and zip/jar files>
3. 
/dev/null ：代表空设备文件
>  ：代表重定向到哪里，例如：echo "123" > /home/123.txt
1  ：表示stdout标准输出，系统默认值是1，所以">/dev/null"等同于"1>/dev/null"
2  ：表示stderr标准错误
&  ：表示等同于的意思，2>&1，表示2的输出重定向等同于1

1 > /dev/null 2>&1 语句含义：
1 > /dev/null ： 首先表示标准输出重定向到空设备文件，也就是不输出任何信息到终端，说白了就是不显示任何信息。
2>&1 ：接着，标准错误输出重定向（等同于）标准输出，因为之前标准输出已经重定向到了空设备文件，所以标准错误输出也重定向到空设备文件。

启动核心命令：
$ZEPPELIN_RUNNER $JAVA_OPTS -cp $CLASSPATH $ZEPPELIN_MAIN

$ZEPPELIN_RUNNER: ${JAVA_HOME}/bin/java
$JAVA_OPTS: ${ZEPPELIN_JAVA_OPTS} -Dfile.encoding=${ZEPPELIN_ENCODING} ${ZEPPELIN_MEM} -Dzeppelin.log.file=${ZEPPELIN_LOGFILE}
$CLASSPATH: ${ZEPPELIN_CLASSPATH}
$ZEPPELIN_MAIN: com.nflabs.zeppelin.server.ZeppelinServer

----
$ZEPPELIN_CLASSPATH: ${ZEPPELIN_CONF_DIR} $jar:$ZEPPELIN_CLASSPATH :${ZEPPELIN_HOME}/zeppelin-zengine/target/classes :${ZEPPELIN_HOME}/zeppelin-server/target/classes :${HADOOP_CONF_DIR} :${ZEPPELIN_CLASSPATH} ${ZEPPELIN_CLASSPATH}
$ZEPPELIN_JAVA_OPTS: 
$ZEPPELIN_ENCODING: "UTF-8"
$ZEPPELIN_MEM: -Xmx1024m -XX:MaxPermSize=512m
$ZEPPELIN_LOGFILE: ${ZEPPELIN_LOG_DIR}/zeppelin-${ZEPPELIN_IDENT_STRING}-${HOSTNAME}.log
'''


com.nflabs.zeppelin.server.ZeppelinServer

'''
应该是有两个server，一个是web server，负责web页面上的交互；另一个是notebook server，负责执行
有关notebook内容的操作吧。
不太理解的是，这里的两个server都是和前台进行连接的，一个是普通连接，另一个是websocket连接。好像
水星也是这样搞的，我不太了解websocket，不好说什么。刚开始我还理解为notebook server是在web server之后，
由web server来调用notebook server里的东西呢，即对外只暴露web server。目前的情况是对外同时暴露了
web server和notebook server。
'''
'''
以下是主要分析的ZeppelinServer启动代码：
花2小时了解java里jettyServer的模式；
花1小时了解hood[钩子]技术；
'''
  public static void main(String[] args) throws Exception {
    ZeppelinConfiguration conf = ZeppelinConfiguration.create();
    conf.setProperty("args", args);

    final Server jettyServer = setupJettyServer(conf);
    notebookServer = setupNotebookServer(conf);

    // REST api
    final ServletContextHandler restApi = setupRestApiContextHandler();
    /** NOTE: Swagger-core is included via the web.xml in zeppelin-web
     * But the rest of swagger is configured here
     */
    final ServletContextHandler swagger = setupSwaggerContextHandler(conf);

    // Web UI
    final WebAppContext webApp = setupWebAppContext(conf);
    //Below is commented since zeppelin-docs module is removed.
    //final WebAppContext webAppSwagg = setupWebAppSwagger(conf);

    // add all handlers
    ContextHandlerCollection contexts = new ContextHandlerCollection();
    //contexts.setHandlers(new Handler[]{swagger, restApi, webApp, webAppSwagg});
    contexts.setHandlers(new Handler[]{swagger, restApi, webApp});
    jettyServer.setHandler(contexts);

    notebookServer.start();
    LOG.info("Start zeppelin server");
    jettyServer.start();
    LOG.info("Started");

    Runtime.getRuntime().addShutdownHook(new Thread(){
      @Override public void run() {
        LOG.info("Shutting down Zeppelin Server ... ");
        try {
          notebook.getInterpreterFactory().close();

          jettyServer.stop();
          notebookServer.stop();
        } catch (Exception e) {
          LOG.error("Error while stopping servlet container", e);
        }
        LOG.info("Bye");
      }
    });

        // when zeppelin is started inside of ide (especially for eclipse)
    // for graceful shutdown, input any key in console window
    if (System.getenv("ZEPPELIN_IDENT_STRING") == null) {
      try {
        System.in.read();
      } catch (IOException e) {
      }
      System.exit(0);
    }

    jettyServer.join();
  }



