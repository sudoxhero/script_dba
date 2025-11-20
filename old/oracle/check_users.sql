set linesize 30000

col USERNAME for a30
col PASSWORD for a10
col ACCOUNT_STATUS for a20
col LOCK_DATE for a10
col EXPIRY_DA for a10
col DEFAULT_TABLESPACE for a10             
col TEMPORARY_TABLESPACE for a10
col LOCAL_TEMP_TABLESPACE for a10
col CREATED for a10
col PROFILE for a10
col INITIAL_RSRC_CONSUMER_GROUP for a30                                                                                             
col EXTERNAL_NAME for a10                                                                                                                     
col PASSWORD_VERSIONS for a10
col last_login for a25

select * from dba_users;

