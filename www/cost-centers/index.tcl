# /packages/intranet-cost/www/cost-centers/index.tcl
#
# Copyright (C) 2003 - now Project Open Business Solutions S.L.
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_page_contract {
    Show the permissions for all cost_centers in the system

    @author frank.bergmann@project-open.com
} {
    { return_url "" }
}

# ------------------------------------------------------
# Defaults & Security
# ------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]
set user_is_admin_p [im_is_user_site_wide_or_intranet_admin $user_id]

if {!$user_is_admin_p} {
    ad_return_complaint 1 "You have insufficient privileges to use this page"
    return
}

set page_title "Cost Centers"
set context_bar [im_context_bar $page_title]
set context ""

set cost_center_url "/intranet-cost/cost-centers/new"
set group_url "/admin/groups/one"

set bgcolor(0) " class=rowodd"
set bgcolor(1) " class=roweven"

if {"" == $return_url} { set return_url [ad_conn url] }


set help_str "<ul><li>To show CC in right order please set 'Cost Center Code' accordingly. For additional help please see 'Context Help' that is provided for this page</li>" 
append help_str "<li><span>Please note:</span><br>Deleting Cost Centers from a productive system should be the exception. Whenever possible, set them to 'inactive'."
append help_str "If a Cost Center is removed from the system, all related costs will be transfered to the default Cost Center 'The Company'.</li></ul>"
set help_txt [lang::message::lookup "" intranet-cost.Cost_Center_help $help_str]


set table_header "
<tr>
  <td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>
  <td class=rowtitle align=center>[lang::message::lookup "" intranet-cost.CostCenter "Cost Center Code"]</td>
  <td class=rowtitle align=center>[lang::message::lookup "" intranet-cost.Type "Type"]</td>
  <td class=rowtitle align=center>[lang::message::lookup "" intranet-cost.DepartmentP "Dpt.?"]</td>
  <td class=rowtitle align=center>[lang::message::lookup "" intranet-cost.CostCenterStatus "Status"]</td>
  <td class=rowtitle align=center>[lang::message::lookup "" intranet-cost.InheritFrom "Inherit Permsissons From"]</td>
  <td class=rowtitle align=center>[lang::message::lookup "" intranet-cost.Manager "Manager"]</td>
  <td class=rowtitle align=center>[lang::message::lookup "" intranet-cost.Employees "Employees"]</td>
  <td class=rowtitle>[im_gif -translate_p 1 del "Delete Cost Center"]</td>
</tr>
"

# ------------------------------------------------------
# Main SQL: Extract the permissions for all Cost Centers
# ------------------------------------------------------

set main_sql "
	select distinct
		m.*,
		im_name_from_id(m.cost_center_type_id) as cost_center_type_name,
		length(cost_center_code) / 2 as indent_level,
		(9 - (length(cost_center_code)/2)) as colspan_level,
		im_name_from_user_id(m.manager_id) as manager_name,
		e.employee_id as employee_id,
		im_name_from_user_id(e.employee_id) as employee_name,
		acs_object__name(o.context_id) as context,
                o.tree_sortkey,
                tree_level(o.tree_sortkey) as tree_level
	from
		acs_objects o,
		im_cost_centers m
		LEFT JOIN (
			select	e.*
			from	im_employees e,
				cc_users u
			where	e.employee_id = u.user_id and
				u.member_state = 'approved'
		) e ON (e.department_id = m.cost_center_id)
	where
		o.object_id = m.cost_center_id
	order by o.tree_sortkey,employee_name
"

set table ""
set ctr 0
set old_package_name ""
set last_id 0
set space "&nbsp; &nbsp; &nbsp; "

db_foreach cost_centers $main_sql {
    incr ctr
    set object_id $cost_center_id
    append table "\n<tr$bgcolor([expr $ctr % 2])>\n"

    set sub_indent ""
    for {set i 1} {$i < $tree_level} {incr i} { append sub_indent $space }

    set cost_center_status [im_category_from_id $cost_center_status_id] 

    if { $last_id != $cost_center_id } {
        append table "
		<td><nobr><font size=-4>(#$cost_center_id)</font>$sub_indent <a href=$cost_center_url?cost_center_id=$cost_center_id&return_url=$return_url>$cost_center_name</a></nobr></td>
	        <td>$cost_center_code</td>
		<td>$cost_center_type_name</td>
		<td>$department_p</td>
		<td>$cost_center_status</td>
		<td>$context</td>
		<td><a href=[export_vars -base "/intranet/users/view" -override {{user_id $manager_id}}]>$manager_name</a></td>
	"
    } else {
	append table "<td colspan='6'></td>"
    }

    append table "
	  <td>
	      <nobr><a href=[export_vars -base "/intranet/users/view" -override {{user_id $employee_id}}]>$employee_name</a></nobr>
	  </td>
	  <td>
       "
    
    # Add checkbox to last column when cc line
    if {$last_id!=$cost_center_id} { append table "<input type=checkbox name=cost_center_id.$cost_center_id>" }

    append table "
	  </td>
	</tr>
    "
    set last_id $cost_center_id
}

append table "
        <tr>
          <td colspan='10' align=right><input type='submit' value='Del'></td>
        </tr>
"

append left_navbar_html "
        <div class='filter-block'>
	        <div class='filter-title'>#intranet-cost.AdminCostCenter#</div>
		<ul>
		    <li><a href=new?[export_url_vars return_url]>[lang::message::lookup "" intranet-cost.CreateNewCostCenter "Create new Cost Center"]</a</li>
		</ul>
        </div>
"
