set linesize 30000
col "File Path" for a50
col Status for a10
col "File Name" for a30
col "File Directory" for a50

with withcontrolfile as (select * from v$controlfile)
                    select 
                      c.name as "File Path",
                      decode(c.status, null, 'VALID', c.status) "Status", 
                      fileanddir.sname "File Name", 
                      fileanddir.dname "File Directory" 
                    from 
                      (select substr(maxgroupby.xname,
                                 decode (maxgroupby.msizex,length(maxgroupby.xname), 1, 
                                     maxgroupby.msizex+1)) sname, substr(maxgroupby.xname,1,
                                     decode(maxgroupby.msizex,0,length(maxgroupby.xname),maxgroupby.msizex
                                           )) 
                                     dname, 
                                     maxgroupby.xname maxgroupbyname from 
                                     (select max(sizex) msizex, xname from 
                                        (select instr (withcontrolfile.name,'/', -1)  sizex,
                                           withcontrolfile.name xname from withcontrolfile
                                         union all select instr (withcontrolfile.name,':', -1) sizex, 
                                           withcontrolfile.name xname from withcontrolfile
                                         union all select instr (withcontrolfile.name,'\', -1) sizex, 
                                           withcontrolfile.name xname from withcontrolfile
                                         union all select 0 sizex , withcontrolfile.name xname from withcontrolfile
                                         )
                                       group by xname
                                     ) maxgroupby
                      )
                      fileanddir, 
                      v$controlfile c 
                    where 
                      maxgroupbyname = c.name 
                    order by 1;
                    
