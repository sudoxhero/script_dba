prompt ###################################
prompt Local do recovery file dest 
prompt ###################################

show parameter db_recovery_file_dest

set linesize 30000
col name for a50

select * from v$recovery_file_dest;

prompt #########################################
prompt Verificando espaço no recovery file dest 
prompt #########################################

select * from v$recovery_area_usage;

prompt #########################################
prompt Verificando espaço no flash recovery area 
prompt #########################################

select * from v$flash_recovery_area_usage;
