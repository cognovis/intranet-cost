-- /packages/intranet-cost/sql/oracle/intranet-cost-create.sql
--
-- Project/Open Cost Core
-- 040207 fraber@fraber.de
--
-- Copyright (C) 2004 Project/Open
--
-- All rights including reserved. To inquire license terms please 
-- refer to http://www.project-open.com/modules/<module-key>


-------------------------------------------------------------
-- "Cost Centers"
--
-- Cost Centers (actually: cost-, revenue- and investment centers) 
-- are used to model the organizational hierarchy of a company. 
-- Departments are just a special kind of cost centers.
-- Please note that this hierarchy is completely independet of the
-- is-manager-of hierarchy between employees.
--
-- Centers (cost centers) are a "vertical" structure following
-- the organigram of a company, as oposed to "horizontal" structures
-- such as projects.
--
-- Center_id references groups. This group is the "admin group"
-- of this center and refers to the users who are allowed to
-- use or administer the center. Admin members are allowed to
-- change the center data. ToDo: It is not clear what it means to 
-- be a regular menber of the admin group.
--
-- The manager_id is the person ultimately responsible for
-- the center. He or she becomes automatically "admin" member
-- of the "admin group".
--
-- Access to centers are controled using the OpenACS permission
-- system. Privileges include:
--	- administrate
--	- input_costs
--	- confirm_costs
--	- propose_budget
--	- confirm_budget

begin
    acs_object_type.create_type (
	supertype =>		'acs_object',
	object_type =>		'im_cost_center',
	pretty_name =>		'Cost Center',
	pretty_plural =>	'Cost Centers',
	table_name =>		'im_centers',
	id_column =>		'cost_center_id',
	package_name =>		'im_cost_center',
	type_extension_table =>	null,
	name_method =>		'im_cost_center.name'
    );
end;
/
show errors


create table im_cost_centers (
	cost_center_id		integer
				constraint im_cost_centers_pk
				primary key
				constraint im_cost_centers_id_fk
				references acs_objects,
	name			varchar(100) not null,
	cost_center_type_id	integer not null
				constraint im_cost_centers_type_fk
				references im_categories,
	cost_center_status_id	integer not null
				constraint im_cost_centers_status_fk
				references im_categories,
				-- Where to report costs?
				-- The toplevel_center has parent_id=null.
	parent_id		integer 
				constraint im_cost_centers_parent_fk
				references im_cost_centers,
				-- Who is responsible for this cost_center?
	manager_id		integer
				constraint im_cost_centers_manager_fk
				references users,
	description		varchar(4000),
	note			varchar(4000)
);
create index im_cost_centers_parent_id_idx on im_cost_centers(parent_id);
create index im_cost_centers_manager_id_idx on im_cost_centers(manager_id);


create or replace package im_cost_center
is
    function new (
	cost_center_id	in integer,
	object_type	in varchar,
	creation_date	in date,
	creation_user	in integer,
	creation_ip	in varchar,
	context_id	in integer,

	name		in varchar,
	type_id		in integer,
	status_id	in integer,
	parent_id	in integer,
	manager_id	in integer,
	description	in varchar,
	note		in varchar
    ) return im_cost_centers.cost_center_id%TYPE;

    procedure del (cost_center_id in integer);
    procedure name (cost_center_id in integer);
end im_cost_center;
/
show errors


create or replace package body im_cost_center
is

    function new (
	cost_center_id	in integer,
	object_type	in varchar,
	creation_date	in date,
	creation_user	in integer,
	creation_ip	in varchar,
	context_id	in integer,

	name		in varchar,
	type_id		in integer,
	status_id	in integer,
	parent_id	in integer,
	manager_id	in integer,
	description	in varchar,
	note		in varchar
    ) return im_cost_centers.cost_center_id%TYPE
    is
	v_cost_center_id	im_cost_centers.cost_center_id%TYPE;
    begin
	v_cost_center_id := acs_object.new (
		object_id =>		cost_center_id,
		object_type =>		object_type,
		creation_date =>	creation_date,
		creation_user =>	creation_user,
		creation_ip =>		creation_ip,
		context_id =>		context_id
	);

	insert into im_cost_centers (
		cost_center_id, name, cost_center_type_id, 
		cost_center_status_id, parent_id, manager_id, description, note
	) values (
		v_cost_center_id, name, type_id, 
		status_id, parent_id, manager_id, description, note
	);
	return v_cost_center_id;
    end new;


    -- Delete a single cost_center (if we know its ID...)
    procedure del (cost_center_id in integer)
    is
	v_cost_center_id	integer;
    begin
	-- copy the variable to desambiguate the var name
	v_cost_center_id := cost_center_id;

	-- Erase the im_cost_centers item associated with the id
	delete from 	im_cost_centers
	where		cost_center_id = v_cost_center_id;

	-- Erase all the priviledges
	delete from 	acs_permissions
	where		object_id = v_cost_center_id;

	-- Finally delete the object iself
	acs_object.del(v_cost_center_id);
    end del;


    procedure name (cost_center_id in integer)
    is
	v_name	im_cost_centers.name%TYPE;
    begin
	select	name
	into	v_name
	from	im_cost_centers
	where	cost_center_id = cost_center_id;
    end name;
end im_cost_center;
/
show errors


-------------------------------------------------------------
-- Setup the status and type categories

-- 3000-3099    Intranet Cost Center Type
-- 3100-3199    Intranet Cost Center Status
-- 3200-3399	reserved for cost centers
-- 3400-3499	Intranet Cost Investment Type
-- 3500-3599	Intranet Cost Investment Status


-- Intranet Cost Center Type
delete from im_categories where category_id >= 3000 and category_id < 3100;
INSERT INTO im_categories VALUES (3001,'Cost Center','','Intranet Cost Center Type',1,'f','');
INSERT INTO im_categories VALUES (3002,'Profit Center','','Intranet Cost Center Type',1,'f','');
INSERT INTO im_categories VALUES (3003,'Investment Center','','Intranet Cost Center Type',1,'f','');
INSERT INTO im_categories VALUES (3004,'Subdepartment','Department without budget responsabilities','Intranet Cost Center Type',1,'f','');
commit;
-- reserved until 3099


-- Intranet Cost Center Type
delete from im_categories where category_id >= 3100 and category_id < 3200;
INSERT INTO im_categories VALUES (3101,'Active','','Intranet Cost Center Status',1,'f','');
INSERT INTO im_categories VALUES (3102,'Inactive','','Intranet Cost Center Status',1,'f','');
commit;
-- reserved until 3099





-------------------------------------------------------------
-- Setup the cost_centers of a small consulting company that
-- offers strategic consulting projects and IT projects,
-- both following a fixed methodology (number project phases).


declare
    v_the_company_center	integer;
    v_admin_center		integer;
    v_sales_center		integer;
    v_it_center			integer;
    v_projects_center		integer;
begin

    -- -----------------------------------------------------
    -- Main Center
    -- -----------------------------------------------------

    -- The Company itself: Profit Center (3002) with status "Active" (3101)
    -- This should be the only center with parent=null...
    v_the_company_center := im_cost_center.new (
	name =>		'The Company',
	type_id =>	3002,
	status_id =>	3101,
	parent_id => 	null,
	manager_id =>	null,
	description =>	'The top level center of the company',
	note =>		''
    );


    -- The Administrative Dept.: A typical cost center (3001)
    -- We asume a small company, so there is only one manager
    -- taking budget control of Finance, Accounting, Legal and
    -- HR stuff.
    --
    v_user_center := im_cost_center.new (
	name =>		'Administration',
	type_id =>	3001,
	status_id =>	3101,
	parent_id => 	v_the_company_center,
	manager_id =>	null,
	description =>	'Administration Cervice Center',
	note =>		''
    );

    -- Sales & Marketing Cost Center (3001)
    -- Project oriented companies normally doesn't have a lot 
    -- of marketing, so we don't overcomplicate here.
    --
    v_user_center := im_cost_center.new (
	name =>		'Sales & Marketing',
	type_id =>	3001,
	status_id =>	3101,
	parent_id => 	v_the_company_center,
	manager_id =>	null,
	description =>	'Takes all sales related activities, as oposed to project execution.',
	note =>		''
    );

    -- Sales & Marketing Cost Center (3001)
    -- Project oriented companies normally doesn't have a lot 
    -- of marketing, so we don't overcomplicate here.
    --
    v_user_center := im_cost_center.new (
	name =>		'Sales & Marketing',
	type_id =>	3001,
	status_id =>	3101,
	parent_id => 	v_the_company_center,
	manager_id =>	null,
	description =>	'Takes all sales related activities, as oposed to project execution.',
	note =>		''
    );

end;
/
show errors


-------------------------------------------------------------
-- "Investments"
--
-- Investments are purchases of larger "investment items"
-- that are not treated as a cost item immediately.
-- Instead, investments are "amortized" over time
-- (monthly, quarterly or yearly) until their non-amortized
-- valeu is zero. A new cost item cost items is generated for 
-- every amortization interval.
--
-- The amortized amount of costs is calculated by summing up
-- all im_cost_items with the specific investment_id
--
create table im_cost_assets (
	asset_id		integer
				constraint im_cost_assets_pk
				primary key
				constraint im_cost_assets_id_fk
				references acs_objects,
	name			varchar(400),
	asset_status_id		integer
				constraint im_cost_assets_status_fk
				references im_categories,
	asset_type_id		integer
				constraint im_cost_assets_type_fk
				references im_categories,
	amount			number(12,3),
	currency		char(3)
				constraint im_cost_assets_currency_fk
				references currency_codes(iso),
	amort_start_date	date,
	-- amortize over how many months?
	amort_period_months	integer,
	description		varchar(4000)
);



-- Setup the status and type categories
-- 3000-3099    Intranet Cost Center Type
-- 3100-3199    Intranet Cost Center Status
-- 3200-3399	reserved for cost centers
-- 3400-3499	Intranet Cost Asset Type
-- 3500-3599	Intranet Cost Asset Status
-- 3600-3699	Intranet Cost Asset Amortization Interval

-- Intranet Cost Asset Type
delete from im_categories where category_id >= 3400 and category_id < 3500;
INSERT INTO im_categories VALUES (3401,'Other','','Intranet Cost Asset Type',1,'f','');
INSERT INTO im_categories VALUES (3402,'Computer Hardware','','Intranet Cost Asset Type',1,'f','');
INSERT INTO im_categories VALUES (3403,'Computer Software','','Intranet Cost Asset Type',1,'f','');
INSERT INTO im_categories VALUES (3404,'Office Furniture','','Intranet Cost Asset Type',1,'f','');
commit;
-- reserved until 3499

-- Intranet Cost Asset Status
delete from im_categories where category_id >= 3500 and category_id < 3600;
INSERT INTO im_categories VALUES (3501,'Active','','Intranet Cost Asset Status',1,'f','Currently being amortized');
INSERT INTO im_categories VALUES (3502,'Deleted','','Intranet Cost Asset Status',1,'f','Deleted - was an error');
INSERT INTO im_categories VALUES (3503,'Amortized','','Intranet Cost Asset Status',1,'f','Finished amortization - no remaining book value');
commit;
-- reserved until 3599

-- Intranet Cost Asset Amortization Internval
delete from im_categories where category_id >= 3600 and category_id < 3700;
INSERT INTO im_categories VALUES (3601,'Month','','Intranet Cost Asset Amortization Internval',1,'f','Currently being amortized');
INSERT INTO im_categories VALUES (3602,'Quarter','','Intranet Cost Asset Amortization Internval',1,'f','Currently being amortized');
INSERT INTO im_categories VALUES (3603,'Year','','Intranet Cost Asset Amortization Internval',1,'f','Currently being amortized');
commit;
-- reserved until 3699



-------------------------------------------------------------
-- Costs
--
-- Costs is the superclass for all financial items such as 
-- Invoices, Quotes, Purchase Orders, Bills (from providers), 
-- Travel Costs, Payroll Costs, Fixed Costs, Amortization Costs,
-- etc. in order to allow for simple SQL queries revealing the
-- financial status of a company.
--
-- Costs are also used for controlling, namely by assigning costs
-- to projects, customers and cost centers in order to allow for 
-- (more or less) accurate profit & loss calculation.
-- This assignment sometimes requires to split a large cost item
-- into several smaller items in order to assign them more 
-- accurately to project, customers or cost centers ("redistribution").
--
create table im_costs (
	cost_id			integer
				constraint im_costs_pk
				primary key,
				constraint im_costs_item_fk
				references acs_objects,
	name			varchar(400),
	cost_status_id		integer
				constraint im_costs_status_fk
				references im_categories,
	cost_type_id		integer
				constraint im_costs_type_fk
				references im_categories,
	project_id		integer
				constraint im_costs_project_fk
				references im_projects,
	customer_id		integer
				constraint im_costs_customer_fk
				references im_customers,
	asset_id		integer
				constraint im_costs_asset_fk
				references im_assets,
	due_date		date,
	payment_date		date,
	amount			number(12,3),
	currency		char(3) references currency_codes(iso),
	-- variable or fixed costs?
	variable_type_id	integer
				constraint im_cost_variable_fk
				references im_categories,
	-- cost has been split into several small cost items?
	redistributed_p		char(1)
				constraint im_costs_var_ck
				check redistributed_p in ('t','f'),
	-- points to its parent if the parent was "distributed"
	parent_cost_id		integer
				constraint im_costs_parent_fk
				references im_costs,
	-- "real cost", "planning" of "quote or purchase order"
	planning_type_id	integer
				constraint im_costs_planning_type_fk
				references im_categories,
	description		varchar(4000),
);
