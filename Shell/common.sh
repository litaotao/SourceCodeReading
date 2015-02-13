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
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#


'''
# 这里和zeppelin-daemon.sh里写的有点区别，也许可以更好的写成 FWDIR="$(cd $(dirname "$0")>/dev/null; pwd)"
  不过这里等我弄清楚了linux的重定向后再pull request了。
'''
FWDIR="$(cd $(dirname "$0"); pwd)"

'''
# 符号说明[[]]:　这组符号与 [] 符号，基本上作用相同，但它允许在其中直接使用 || 与 && 逻辑等符号，相当于是一个高级的[]。
  这里在if语句中的-z是属于if语句参数，常见if参数如下：

  文件比较运算符
　　-e filename 如果 filename 存在，则为真 [ -e /var/log/syslog ]
　　-d filename 如果 filename 为目录，则为真 [ -d /tmp/mydir ]
　　-f filename 如果 filename 为常规文件，则为真 [ -f /usr/bin/grep ]
　　-L filename 如果 filename 为符号链接，则为真 [ -L /usr/bin/grep ]
　　-r filename 如果 filename 可读，则为真 [ -r /var/log/syslog ]
　　-w filename 如果 filename 可写，则为真 [ -w /var/mytmp.txt ]
　　-x filename 如果 filename 可执行，则为真 [ -L /usr/bin/grep ]
　　filename1 -nt filename2 如果 filename1 比 filename2 新，则为真 [ /tmp/install/etc/services -nt /etc/services ] 
　　filename1 -ot filename2 如果 filename1 比 filename2 旧，则为真 [ /boot/bzImage -ot arch/i386/boot/bzImage ]
　　
  字符串比较运算符 (请注意引号的使用，这是防止空格扰乱代码的好方法)
    -z string 如果 string 长度为零，则为真 [ -z $myvar ]
　　-n string 如果 string 长度非零，则为真 [ -n $myvar ]
　　string1 = string2 如果 string1 与 string2 相同，则为真 [ $myvar = one two three ]
　　string1 != string2 如果 string1 与 string2 不同，则为真 [ $myvar != one two three ]
　　
  算术比较运算符
　　num1 -eq num2 等于 [ 3 -eq $mynum ]
　　num1 -ne num2 不等于 [ 3 -ne $mynum ]
　　num1 -lt num2 小于 [ 3 -lt $mynum ]
　　num1 -le num2 小于或等于 [ 3 -le $mynum ]
　　num1 -gt num2 大于 [ 3 -gt $mynum ]
　　num1 -ge num2 大于或等于 [ 3 -ge $mynum ]
'''
if [[ -z "${ZEPPELIN_HOME}" ]]; then
  # Make ZEPPELIN_HOME look cleaner in logs by getting rid of the
  # extra ../
  export ZEPPELIN_HOME="$(cd "${FWDIR}/.."; pwd)"
fi

if [[ -z "${ZEPPELIN_CONF_DIR}" ]]; then
  export ZEPPELIN_CONF_DIR="${ZEPPELIN_HOME}/conf"
fi

if [[ -z "${ZEPPELIN_LOG_DIR}" ]]; then
  export ZEPPELIN_LOG_DIR="${ZEPPELIN_HOME}/logs"
fi

if [[ -z "${ZEPPELIN_NOTEBOOK_DIR}" ]]; then
  export ZEPPELIN_NOTEBOOK_DIR="${ZEPPELIN_HOME}/notebook"
fi

if [[ -z "$ZEPPELIN_PID_DIR" ]]; then
  export ZEPPELIN_PID_DIR="${ZEPPELIN_HOME}/run"
fi

if [[ -z "${ZEPPELIN_WAR}" ]]; then
  if [[ -d "${ZEPPELIN_HOME}/zeppelin-web/src/main/webapp" ]]; then
    export ZEPPELIN_WAR="${ZEPPELIN_HOME}/zeppelin-web/src/main/webapp"
  else
    export ZEPPELIN_WAR=$(find -L "${ZEPPELIN_HOME}" -name "zeppelin-web*.war")
  fi
fi

if [[ -z "${ZEPPELIN_API_WAR}" ]]; then
  if [[ -d "${ZEPPELIN_HOME}/zeppelin-docs/src/main/swagger" ]]; then
    export ZEPPELIN_API_WAR="${ZEPPELIN_HOME}/zeppelin-docs/src/main/swagger"
  else
    export ZEPPELIN_API_WAR=$(find -L "${ZEPPELIN_HOME}" -name "zeppelin-api-ui*.war")
  fi
fi

if [[ -z "$ZEPPELIN_INTERPRETER_DIR" ]]; then
  export ZEPPELIN_INTERPRETER_DIR="${ZEPPELIN_HOME}/interpreter"
fi

if [[ -f "${ZEPPELIN_CONF_DIR}/zeppelin-env.sh" ]]; then
  . "${ZEPPELIN_CONF_DIR}/zeppelin-env.sh"
fi

ZEPPELIN_CLASSPATH+=":${ZEPPELIN_CONF_DIR}"

function addJarInDir(){
  if [[ -d "${1}" ]]; then
    for jar in $(find -L "${1}" -maxdepth 1 -name '*jar'); do
      ZEPPELIN_CLASSPATH="$jar:$ZEPPELIN_CLASSPATH"
    done
  fi
}
  
addJarInDir "${ZEPPELIN_HOME}"
addJarInDir "${ZEPPELIN_HOME}/lib"
addJarInDir "${ZEPPELIN_HOME}/zeppelin-zengine/target/lib"
addJarInDir "${ZEPPELIN_HOME}/zeppelin-server/target/lib"
addJarInDir "${ZEPPELIN_HOME}/zeppelin-web/target/lib"

if [[ -d "${ZEPPELIN_HOME}/zeppelin-zengine/target/classes" ]]; then
  ZEPPELIN_CLASSPATH+=":${ZEPPELIN_HOME}/zeppelin-zengine/target/classes"
fi

if [[ -d "${ZEPPELIN_HOME}/zeppelin-server/target/classes" ]]; then
  ZEPPELIN_CLASSPATH+=":${ZEPPELIN_HOME}/zeppelin-server/target/classes"
fi

if [[ ! -z "${SPARK_HOME}" ]] && [[ -d "${SPARK_HOME}" ]]; then
  addJarInDir "${SPARK_HOME}"
fi

if [[ ! -z "${HADOOP_HOME}" ]] && [[ -d "${HADOOP_HOME}" ]]; then
  addJarInDir "${HADOOP_HOME}"
fi

export ZEPPELIN_CLASSPATH
export SPARK_CLASSPATH+=":${ZEPPELIN_CLASSPATH}"
export CLASSPATH+=":${ZEPPELIN_CLASSPATH}"

# Text encoding for 
# read/write job into files,
# receiving/displaying query/result.
if [[ -z "${ZEPPELIN_ENCODING}" ]]; then
  export ZEPPELIN_ENCODING="UTF-8"
fi

if [[ -z "$ZEPPELIN_MEM" ]]; then
  export ZEPPELIN_MEM="-Xmx1024m -XX:MaxPermSize=512m"
fi

# revised by taotao.li
JAVA_OPTS+="${ZEPPELIN_JAVA_OPTS} -Dfile.encoding=${ZEPPELIN_ENCODING} ${ZEPPELIN_MEM} -Dscala.usejavacp=true"
export JAVA_OPTS

if [[ -n "${JAVA_HOME}" ]]; then
  ZEPPELIN_RUNNER="${JAVA_HOME}/bin/java"
else
  ZEPPELIN_RUNNER=java
fi

export ZEPPELIN_RUNNER

if [[ -z "$ZEPPELIN_IDENT_STRING" ]]; then
  export ZEPPELIN_IDENT_STRING="${USER}"
fi

if [[ -z "$DEBUG" ]]; then
  export DEBUG=0
fi
