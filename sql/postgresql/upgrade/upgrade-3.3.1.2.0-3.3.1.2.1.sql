-- upgrade-3.3.1.2.0-3.3.1.2.1.sql

SELECT acs_log__debug('/packages/intranet-cost/sql/postgresql/upgrade/upgrade-3.3.1.2.0-3.3.1.2.1.sql','');



update im_component_plugins 
set title_tcl = 'lang::message::lookup "" intranet-timesheet2.Timesheet "Timesheet"' 
where title_tcl = 'lang::message::lookup "" intranet-timesheet.Timesheet "Timesheet"'
;
