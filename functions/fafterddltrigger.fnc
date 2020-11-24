CREATE OR REPLACE FUNCTION public.fafterddltrigger (
)
RETURNS event_trigger AS
$body$
declare
    rec record;
    recdrop record;
    command varchar;
    cols varchar;
    colnames varchar;
    paramnames varchar;
    pk varchar;
    pktype varchar;
    strupdate varchar;
    tname varchar;
begin
	for rec in (SELECT * FROM pg_event_trigger_ddl_commands() WHERE command_tag in ('CREATE TABLE','CREATE TABLE AS','ALTER TABLE')) loop
    --
      select (regexp_matches(replace(rec.object_identity,'"',''),'[A-Za-z0-9]+[\.|\_]?[A-Za-z0-9\_]*'))[1] into tname
       limit 1;
      SELECT pg_attribute.attname, format_type(pg_attribute.atttypid, pg_attribute.atttypmod) 
        INTO pk, pktype
        FROM pg_index, pg_class, pg_attribute, pg_namespace 
       WHERE pg_class.oid = tname::regclass 
         and indrelid = pg_class.oid 
         AND pg_class.relnamespace = pg_namespace.oid 
         AND pg_attribute.attrelid = pg_class.oid 
         AND pg_attribute.attnum = any(pg_index.indkey)
         AND indisprimary
       LIMIT 1;
    --
      select string_agg(s.columna,', '),
             string_agg(s.strupdate,','),
             string_agg(s.column_name,','),
             string_agg(s.paramname,',') 
             into cols, strupdate, colnames, paramnames
        from (select concat('a',c.column_name, ' ', c.data_type,case when c.column_default is null then '' else concat(' = ', c.column_default) end) columna,
                     concat(c.column_name, ' = ', 'a',c.column_name) strupdate,
                     c.column_name,
                     concat('a',c.column_name) paramname 	
                from information_schema.columns c 
               where concat(c.table_schema,'.',c.table_name) = tname
                 and c.column_name <> pk
               order by c.column_default nulls first) s; 
--INSERT                 
      command = concat('CREATE or replace FUNCTION ', replace(tname,'.','.fadd'),' (',cols,') RETURNS ',coalesce(pktype,'void'),' AS''
declare
	result ',pktype,';
begin
   ','insert into ',tname,'(',colnames,') values (',paramnames,') returning ',pk,' into result;','
   return result;
END; 
''LANGUAGE ''plpgsql''
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER
PARALLEL UNSAFE;');       
        --
		EXECUTE command;
--UPDATE
      command = concat('CREATE or replace FUNCTION ', replace(tname,'.','.fedit'),
      ' (','a',pk,' ',pktype, case when cols is null then '' else ', ' end, cols,') RETURNS void AS''
begin
   ','update ',tname,' set ',strupdate,' where ',pk, ' = a',pk,';','
END; 
''LANGUAGE ''plpgsql''
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER
PARALLEL UNSAFE;');       
        --
		EXECUTE command;        
    end loop;    
    return; 
/*exception
  when others then
  	return;*/
end;
$body$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER
PARALLEL UNSAFE
COST 100;

COMMENT ON FUNCTION public.fafterddltrigger()
IS 'Function creates automaticly fadd<<table_name>> and fedit<<table_name>> functions for make insert and update on <<table_name>>';

ALTER FUNCTION public.fafterddltrigger ()
  OWNER TO postgres;
