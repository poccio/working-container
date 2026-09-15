#!/bin/bash
# Logger from this post http://www.cubicrace.com/2016/03/log-tracing-mechnism-for-shell-scripts.html

function INFO(){
    echo "[$(date)] [INFO] [${0}] $1"
}

function DEBUG(){
    echo "[$(date)] [DEBUG] [${0}] $1"
}

function ERROR(){
    echo "[$(date)] [ERROR] [${0}] $1" >&2
}
