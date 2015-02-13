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
# 
'''
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

HOSTNAME=$(hostname)
ZEPPELIN_NAME="Zeppelin"
ZEPPELIN_LOGFILE="${ZEPPELIN_LOG_DIR}/zeppelin-${ZEPPELIN_IDENT_STRING}-${HOSTNAME}.log"
ZEPPELIN_OUTFILE="${ZEPPELIN_LOG_DIR}/zeppelin-${ZEPPELIN_IDENT_STRING}-${HOSTNAME}.out"
ZEPPELIN_PID="${ZEPPELIN_PID_DIR}/zeppelin-${ZEPPELIN_IDENT_STRING}-${HOSTNAME}.pid"
ZEPPELIN_MAIN=com.nflabs.zeppelin.server.ZeppelinServer
JAVA_OPTS+=" -Dzeppelin.log.file=${ZEPPELIN_LOGFILE}"

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
