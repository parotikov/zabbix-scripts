#!/bin/bash
 
# Egor Minko. Synchron LLC. May.2012
#
# /etc/zabbix/zabbix_agentd.conf
# Timeout=10 # If You have a lot of emails through your system - you must increase Zabbix Timeout:
# UserParameter=exim4[*],sudo /opt/zexim4 \$1
#
# Yiu will need sudo to use these commands
# /etc/sudoers
# zabbix ALL=NOPASSWD: /opt/zexim4
#
 
zexim4ver="ver 2.1"
rval=0
 
# MULTIPLE PARSERS PROTECTION
LOCK=/tmp/zexim4.pid
while [ -e "$LOCK" ]; do
PID="`cat $LOCK`"
while [ "`ps h -p $PID -o pid,comm|wc -l`" -gt 0 ]
do
sleep 0.$[ ( $RANDOM % 10 ) + 1 ]s
done
done
echo $$ &amp;amp;amp;amp;amp;gt; $LOCK
trap "rm -f $LOCK; exit" INT TERM EXIT
 
# USAGE
function usage()
{
echo "zexim version: $zexim4ver"
echo "usage:"
echo " $0 deliver -- Delivered Messages"
echo " $0 arrive -- Submited Pakets"
echo " $0 error -- Errors Total for Messages"
echo " $0 defer -- Error status: Defered Messages"
echo " $0 unroute -- Error status: Unroutable address"
echo " $0 local -- Local/Virtual delivery of Messages"
echo " $0 complete -- Finished Packets"
echo " $0 reject -- Rejects Total for Packets"
echo " $0 badrelay -- Reject status: Relay not permited"
echo " $0 Pqueue -- Queue size in Packets"
echo " $0 Mqueue -- Queue size in Messages"
echo " $0 frozen -- Frozen Packets"
echo ""
echo " Packet = letter with many recipients"
echo " Message = A single message for one recipient"
echo ""
}
 
# GLOBAL INSTRUCTIONS
CACHETTL="58" # sec
main_log=/var/log/exim4/mainlog
tmp_log=/tmp/exim_log_pars.txt
stats=/tmp/stats.txt
exim=`which exim`
 
function create_data()
{
# CREATING STATS FILE
if [ ! -e "$stats" ] ; then touch $stats ; fi
 
# CREATING TMP FILE
# additional 'sub' in 'awk' used for cutting special chars that breaks next 'sed' parsing. For now: []()
position=`tail -1 $stats |awk '{print $1" "$2" "$3}'`
position_log=`tail -1 $main_log | awk '{sub(/\]/,""); sub(/\[/,""); sub(/\)/,""); sub(/\(/,""); print $1" "$2" "$3}'`
 
# BUILDING REPORT ONLY IF THERE IS DIFFERENCE BETWEEN LAST LINE IN LOG
if [ "$position" == "$position_log" ]
then
vars="0 0 0 0 0 0 0 0 0"
else
if ! grep -qc "" $stats || ! awk '{sub(/\]/,""); sub(/\[/,""); sub(/\)/,""); sub(/\(/,""); print}' $main_log|grep -qc "$position"
then
awk '{sub(/\]/,""); sub(/\[/,""); sub(/\)/,""); sub(/\(/,""); print}' $main_log $main_log &amp;amp;amp;amp;amp;gt; $tmp_log
else
awk '{sub(/\]/,""); sub(/\[/,""); sub(/\)/,""); sub(/\(/,""); print}' $main_log |sed 1,/"$position"/d | sed /"$position"/d &amp;amp;amp;amp;amp;gt; $tmp_log
fi
vars="`awk '\
BEGIN {deliver=0; arrive=0; error=0; local=0; complete=0; reject=0; badrelay=0; defer=0; unroute=0}\
/[-=]&amp;amp;amp;amp;amp;gt;/ { deliver++ }\
/&amp;amp;amp;amp;amp;lt;=/ {arrive++}\
/ \*\* / {error++}\
/[=][=]/ {defer++}\
/al_delivery/ {local++}\
/Completed/ {complete++}\
/rejected/ {reject++}\
/relay not permitted/ {badrelay++}\
/Unrouteable address/ {unroute++}\
END {print deliver" "arrive" "error" "defer" "local" "complete" "reject" "badrelay" "unroute}' $tmp_log`"
fi
 
queue_size="`$exim -bpc`"
recipients="`exipick -bpu |awk '$2==""{print $1}'|grep -vE "^$"|wc -l`"
frozen="`exiqgrep -zi|wc -l`"
echo $position_log $vars $queue_size $recipients $frozen &amp;amp;amp;amp;amp;gt;&amp;amp;amp;amp;amp;gt; $stats
 
}
 
function zabbix_answer()
{
case $CASE_VALUE in
'deliver')
tail -n1 "$stats"|awk '{print $4}'
rval=$?;;
'arrive')
tail -n1 "$stats"|awk '{print $5}'
rval=$?;;
'error')
tail -n1 "$stats"|awk '{print $6}'
rval=$?;;
'defer')
tail -n1 "$stats"|awk '{print $7}'
rval=$?;;
'local')
tail -n1 "$stats"|awk '{print $8}'
rval=$?;;
'complete')
tail -n1 "$stats"|awk '{print $9}'
rval=$?;;
'reject')
tail -n1 "$stats"|awk '{print $10}'
rval=$?;;
'badrelay')
tail -n1 "$stats"|awk '{print $11}'
rval=$?;;
'unroute')
tail -n1 "$stats"|awk '{print $12}'
rval=$?;;
'Pqueue')
tail -n1 "$stats"|awk '{print $13}'
rval=$?;;
'Mqueue')
tail -n1 "$stats"|awk '{print $14}'
rval=$?;;
'frozen')
tail -n1 "$stats"|awk '{print $15}'
rval=$?;;
'version')
echo "$zexim4ver"
rm $LOCK
trap - INT TERM EXIT
exit $rval;;
*)
usage
rm $LOCK
trap - INT TERM EXIT
exit $rval;;
esac
}
 
if [ -s "$stats" ]; then
TIMECACHE=`stat -c"%Z" "$stats"`
else
TIMECACHE=0
fi
 
TIMENOW=`date '+%s'`
if [[ $# == 1 ]];then
CASE_VALUE=$1
if [ "$(($TIMENOW - $TIMECACHE))" -gt "$CACHETTL" ]; then
create_data
fi
zabbix_answer
if [ "$rval" -ne 0 ]; then
echo "ZBX_NOTSUPPORTED"
fi
rm $LOCK
trap - INT TERM EXIT
exit $rval
else
usage
rm $LOCK
trap - INT TERM EXIT
exit 0
fi
