CREATE EVENT TRIGGER afterddltrigger
ON ddl_command_end
WHEN tag IN ('ALTER TABLE', 'CREATE TABLE', 'CREATE TABLE AS')
EXECUTE PROCEDURE public.fafterddltrigger();

COMMENT ON EVENT TRIGGER afterddltrigger
IS 'Trigger after DDL ';

ALTER EVENT TRIGGER afterddltrigger
  OWNER TO postgres;