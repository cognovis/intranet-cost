<?xml version="1.0"?>
<!DOCTYPE queryset PUBLIC "-//OpenACS//DTD XQL 1.0//EN" "/usr/share/emacs/DTDs/xql.dtd">
<!-- packages/intranet-cost/www/list-postgresql.xql -->
<!-- @author  (nsadmin@barna.competitiveness.com) -->
<!-- @creation-date 2004-09-22 -->
<!-- @arch-tag dd0aa941-7721-4e1e-b2c6-95dfa87e9f25 -->
<!-- @cvs-id $Id$ -->

<queryset>
  
  
  <rdbms>
    <type>postgresql</type>
    <version>7.2</version>
  </rdbms>
  
  <fullquery name = "costs_info_query">
    <querytext>
      select
        c.*,
	c.amount as amount_formatted,
	(to_date(to_char(c.effective_date,'YYYY-MM-DD'),'YYYY-MM-DD') + c.payment_days) as due_date_calculated,
	o.object_type,
	url.url as cost_url,
	ot.pretty_name as object_type_pretty_name,
        cust.company_name as customer_name,
        cust.company_path as customer_short_name,
	proj.project_nr,
	prov.company_name as provider_name,
	prov.company_path as provider_short_name,
        im_category_from_id(c.cost_status_id) as cost_status,
        im_category_from_id(c.cost_type_id) as cost_type,
	sysdate - (to_date(to_char(c.effective_date,'YYYY-MM-DD'),'YYYY-MM-DD') + c.payment_days) as overdue
	$extra_select
      from
        dual,
        im_costs c 
        LEFT JOIN
           im_projects proj ON c.project_id=proj.project_id,
	acs_objects o,
	acs_object_types ot,
        im_companies cust,
        im_companies prov,
	(select * from im_biz_object_urls where url_type=:view_mode) url
	$extra_from
      where
        c.customer_id=cust.company_id
        and c.provider_id=prov.company_id
	and c.cost_id = o.object_id
	and o.object_type = url.object_type
	and o.object_type = ot.object_type
	$company_where
        $where_clause
	$extra_where
      $order_by_clause
    </querytext>
  </fullquery>
</queryset>