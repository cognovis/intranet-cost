
-- Cost Center Menu as part of the Finance menu
--
create or replace function inline_0 ()
returns integer as '
declare
        -- Menu IDs
        v_menu                  integer;
        v_finance_menu          integer;

        -- Groups
        v_employees             integer;
        v_accounting            integer;
        v_senman                integer;
        v_customers             integer;
        v_freelancers           integer;
        v_proman                integer;
        v_admins                integer;
begin

    select group_id into v_admins from groups where group_name = ''P/O Admins'';
    select group_id into v_senman from groups where group_name = ''Senior Managers'';
    select group_id into v_accounting from groups where group_name = ''Accounting'';
    select group_id into v_customers from groups where group_name = ''Customers'';
    select group_id into v_freelancers from groups where group_name = ''Freelancers'';

    select menu_id
    into v_finance_menu
    from im_menus
    where label=''finance'';

    v_finance_menu := im_menu__new (
        null,                      -- menu_id
        ''acs_object'',            -- object_type
        now(),                     -- creation_date
        null,                      -- creation_user
        null,                      -- creation_ip
        null,                      -- context_id
        ''intranet-cost'',         -- package_name
        ''finance_cost_centers'',  -- label
        ''Cost Centers'',          -- name
        ''/intranet-cost/cost-centers/index'',     -- url
        90,                        -- sort_order
        v_finance_menu,            -- parent_menu_id
        null                       -- visible_tcl
    );


    PERFORM acs_permission__grant_permission(v_finance_menu, v_admins, ''read'');
    PERFORM acs_permission__grant_permission(v_finance_menu, v_senman, ''read'');
    PERFORM acs_permission__grant_permission(v_finance_menu, v_accounting, ''read'');
--    PERFORM acs_permission__grant_permission(v_finance_menu, v_customers, ''read'');
--    PERFORM acs_permission__grant_permission(v_finance_menu, v_freelancers, ''read'');

    return 0;
end;' language 'plpgsql';

select inline_0 ();
drop function inline_0 ();

