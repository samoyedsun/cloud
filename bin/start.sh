#!/bin/sh

export ROOT=$(pwd)

export DAEMON=false
export NODENAME='"test"'
export DEBUG_MODE='"DEBUG"'
export LOG_PATH='"./run/"'
export ETCDHOST='"127.0.0.1:8101"'
export ENV='"dev"'
while getopts "DKUn:d:l:e:v:" arg
do
    case $arg in
        D)
            export DAEMON=true
            ;;
        K)
            kill `cat $ROOT/run/skynet-test.pid`
            exit 0;
            ;;
        n)  
            export NODENAME='"'$OPTARG'"'
            ;;
        d)  
            export DEBUG_MODE='"'$OPTARG'"'
            ;;
        l) 
            export LOG_PATH='"'$OPTARG'"'
            ;;
        e) 
            export ETCDHOST='"'$OPTARG'"'
            ;;
        v)  
            export ENV='"'$OPTARG'"'
            ;;
        U)
            echo 'start srv_hotfix update' | nc 127.0.0.1 8903
            exit 0;
            ;;

    esac
done

$ROOT/skynet/skynet $ROOT/etc/config.lua
