-- upgrade-3.3.1.1.0-3.3.1.2.0.sql

alter table im_costs
add column read_only_p char(1) default 'f';

