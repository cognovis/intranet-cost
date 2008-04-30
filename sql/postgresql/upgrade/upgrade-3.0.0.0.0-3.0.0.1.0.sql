-- upgrade-3.0.0.0.0-3.0.0.1.0.sql

SELECT acs_log__debug('/packages/intranet-cost/sql/postgresql/upgrade/upgrade-3.0.0.0.0-3.0.0.1.0.sql','');

\i ../../../../intranet-core/sql/postgresql/upgrade/upgrade-3.0.0.0.first.sql

-- Add a new cost type
SELECT im_category_new (3718,'Timesheet Cost','Intranet Cost Type');


-- Some helper functions to make our queries easier to read
create or replace function im_cost_center_label_from_id (integer)
returns varchar as '
DECLARE
        p_id    alias for $1;
        v_name  varchar(50);
BEGIN
        select  cc.cost_center_label
        into    v_name
        from    im_cost_centers cc
        where   cost_center_id = p_id;

        return v_name;
end;' language 'plpgsql';


create or replace function im_cost_nr_from_id (integer)
returns varchar as '
DECLARE
        p_id    alias for $1;
        v_name  varchar(50);
BEGIN
        select cost_nr
        into v_name
        from im_costs
        where cost_id = p_id;

        return v_name;
end;' language 'plpgsql';


