-- upgrade-3.3.1.1.0-3.3.1.2.0.sql

SELECT acs_log__debug('/packages/intranet-cost/sql/postgresql/upgrade/upgrade-3.3.1.1.0-3.3.1.2.0.sql','');



-- Add new fields to files for Files FTS
--
create or replace function inline_0 ()
returns integer as '
declare
	v_count		 integer;
begin
	select count(*) into v_count from user_tab_columns
	where lower(table_name) = ''im_costs'' and lower(column_name) = ''read_only_p'';
	IF v_count > 0 THEN return 0; END IF;

	alter table im_costs
	add column read_only_p char(1) default ''f'';

	return 1;
end;' language 'plpgsql';
select inline_0 ();
drop function inline_0 ();


