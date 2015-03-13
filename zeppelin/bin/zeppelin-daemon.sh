#!/bin/bash
#
# Copyright 2007 The Apache Software Foundation
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# description: Start and stop daemon script for.
#
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
BIN=$(dirname "${BASH_SOURCE-$0}")
BIN=$(cd "${BIN}">/dev/null; pwd)

. "${BIN}/common.sh"
. "${BIN}/functions.sh"
'''
奇了个怪了，$hostname返回为空，$HOSTNAME正常返回ubuntu2，$(hostname)也能正常返回ubuntu2
'''
HOSTNAME=$(hostname)
ZEPPELIN_NAME="Zeppelin"
ZEPPELIN_LOGFILE="${ZEPPELIN_LOG_DIR}/zeppelin-${ZEPPELIN_IDENT_STRING}-${HOSTNAME}.log"
ZEPPELIN_OUTFILE="${ZEPPELIN_LOG_DIR}/zeppelin-${ZEPPELIN_IDENT_STRING}-${HOSTNAME}.out"
ZEPPELIN_PID="${ZEPPELIN_PID_DIR}/zeppelin-${ZEPPELIN_IDENT_STRING}-${HOSTNAME}.pid"
ZEPPELIN_MAIN=com.nflabs.zeppelin.server.ZeppelinServer
JAVA_OPTS+=" -Dzeppelin.log.file=${ZEPPELIN_LOGFILE}"

'''
shell中if语法详见：http://www.tektea.com/archives/2344.html
对文件属性的判断
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
mkdir -p: -p, --parents     no error if existing, make parent directories as needed
'''
if [[ "${ZEPPELIN_NICENESS}" = "" ]]; then
    export ZEPPELIN_NICENESS=0
fi

function initialize_default_directories() {
  if [[ ! -d "${ZEPPELIN_LOG_DIR}" ]]; then
    echo "Log dir doesn't exist, create ${ZEPPELIN_LOG_DIR}"
    $(mkdir -p "${ZEPPELIN_LOG_DIR}")
  fi

  if [[ ! -d "${ZEPPELIN_PID_DIR}" ]]; then
    echo "Pid dir doesn't exist, create ${ZEPPELIN_PID_DIR}"
    $(mkdir -p "${ZEPPELIN_PID_DIR}")
  fi

  if [[ ! -d "${ZEPPELIN_NOTEBOOK_DIR}" ]]; then
    echo "Notebook dir doesn't exist, create ${ZEPPELIN_NOTEBOOK_DIR}"
    $(mkdir -p "${ZEPPELIN_NOTEBOOK_DIR}")
  fi
}

'''
local 简单地理解成局部变量吧。
kill 信号值：
  0： exit code indicates if a signal may be sent，向某一进程发送一个无效的信号，
      如果该进程存在（能够接收信号），echo $?为1，否则为0
  9： cannot be blocked
执行这个函数具体还不知道要干嘛
'''

function stop() {
    local pid
    echo "Going to stop ipython notebook server with spark integrated ..."
    ## judge whether the process is running or not
    if [[ -f "${PIDFILE}" ]]; then
        pid=$(cat ${PIDFILE})
        if kill -0 ${pid} > /dev/null 2>&1; then
            echo -e "ipython notebook server with spark is already running ..."
            return 0
        else
            kill -9 ${pid}
            echo "ipython notebook server with spark stopped ..."
    fi
}


function wait_for_zeppelin_to_die() {
  local pid
  local count
  pid=$1
  count=0
  while [[ "${count}" -lt 10 ]]; do
    $(kill ${pid} > /dev/null 2> /dev/null)
    if kill -0 ${pid} > /dev/null 2>&1; then
      sleep 3
      let "count+=1"
    else
      break
    fi
  if [[ "${count}" == "5" ]]; then
    $(kill -9 ${pid} > /dev/null 2> /dev/null)
  fi
  done
}
'''
start() function in zeppelin-daemon.sh starts java process for Zeppelin server.
It could just simply check if launching this java process succeed or not. But some case, 
for example, even if java process is successfully launched, something still can be wrong 
and Zeppelin server is not serving anything (process is still running),

We wanted CI server detect this case and for doing that, wait_zeppelin_is_up_for_ci() waits 
zeppelin server initializing itself and opening port and ready to serve.
'''
function wait_zeppelin_is_up_for_ci() {
  if [[ "${CI}" == "true" ]]; then
    local count=0;
    while [[ "${count}" -lt 30 ]]; do
      curl -v localhost:8080 2>&1 | grep '200 OK'
      if [[ $? -ne 0 ]]; then
        sleep 1
        continue
      else
        break
      fi
        let "count+=1"
    done
  fi
}


function print_log_for_ci() {
  if [[ "${CI}" == "true" ]]; then
    tail -1000 "${ZEPPELIN_LOGFILE}" | sed 's/^/  /'
  fi
}

function check_if_process_is_alive() {
  local pid
  pid=$(cat ${ZEPPELIN_PID})
  if ! kill -0 ${pid} >/dev/null 2>&1; then
    action_msg "${ZEPPELIN_NAME} process died" "${SET_ERROR}"
    print_log_for_ci
    return 1
  fi
}

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
'''
function start() {
  local pid

  if [[ -f "${ZEPPELIN_PID}" ]]; then
    pid=$(cat ${ZEPPELIN_PID})
    if kill -0 ${pid} >/dev/null 2>&1; then
      echo "${ZEPPELIN_NAME} is already running"
      return 0;
    fi
  fi

  initialize_default_directories

  nohup nice -n $ZEPPELIN_NICENESS $ZEPPELIN_RUNNER $JAVA_OPTS -cp $CLASSPATH $ZEPPELIN_MAIN >> "${ZEPPELIN_OUTFILE}" 2>&1 < /dev/null &
  pid=$!
  if [[ -z "${pid}" ]]; then
    action_msg "${ZEPPELIN_NAME} start" "${SET_ERROR}"
    return 1;
  else
    action_msg "${ZEPPELIN_NAME} start" "${SET_OK}"
    echo ${pid} > ${ZEPPELIN_PID}
  fi

  wait_zeppelin_is_up_for_ci
  sleep 2
  check_if_process_is_alive
}

function stop() {
  local pid
  if [[ ! -f "${ZEPPELIN_PID}" ]]; then
    echo "${ZEPPELIN_NAME} is not running"
    return 0
  fi
  pid=$(cat ${ZEPPELIN_PID})
  if [[ -z "${pid}" ]]; then
    echo "${ZEPPELIN_NAME} is not running"
  else
    wait_for_zeppelin_to_die $pid
    $(rm -f ${ZEPPELIN_PID})
    action_msg "${ZEPPELIN_NAME} stop" "${SET_OK}"
  fi
}

function find_zeppelin_process() {
  local pid

  if [[ -f "${ZEPPELIN_PID}" ]]; then
    pid=$(cat ${ZEPPELIN_PID})
    if ! kill -0 ${pid} > /dev/null 2>&1; then
      action_msg "${ZEPPELIN_NAME} running but process is dead" "${SET_ERROR}"
      return 1
    else
      action_msg "${ZEPPELIN_NAME} is running" "${SET_OK}"
    fi
  else
    action_msg "${ZEPPELIN_NAME} is not running" "${SET_ERROR}"
    return 1
  fi
}

case "${1}" in
  start)
    start
    ;;
  stop)
    stop
    ;;
  reload)
    stop
    start
    ;;
  restart)
    stop
    start
    ;;
  status)
    find_zeppelin_process
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|reload|status}"
esac
