# /packages/intranet-cost_items/www/list.tcl

# ---------------------------------------------------------------
# 1. Page Contract
# ---------------------------------------------------------------

ad_page_contract { 
    List all cost_items together with their payments

    @param order_by cost_item display order 
    @param include_subcost_items_p whether to include sub cost_items
    @param cost_item_status_id criteria for cost_item status
    @param item_type_id criteria for item_type_id
    @param letter criteria for im_first_letter_default_to_a(ug.group_name)
    @param start_idx the starting index for query
    @param how_many how many rows to return

    @author mbryzek@arsdigita.com
    @cvs-id index.tcl,v 3.24.2.9 2000/09/22 01:38:44 kevin Exp
} {
    { order_by "Date" }
    { item_status_id:integer "[im_cost_item_status_created]" } 
    { item_type_id:integer 0 } 
    { customer_id:integer 0 } 
    { provider_id:integer 0 } 
    { letter:trim "" }
    { start_idx:integer "1" }
    { how_many "" }
    { view_name "cost_item_list" }
}

# ---------------------------------------------------------------
# Cost_Item List Page
#
# This is List-Page with some special functions. It consists of the sections:
#    1. Page Contract: 
#	Receive the filter values defined as parameters to this page.
#    2. Defaults & Security:
#	Initialize variables, set default values for filters 
#	(categories) and limit filter values for unprivileged users
#    3. Define Table Columns:
#	Define the table columns that the user can see.
#	Again, restrictions may apply for unprivileged users,
#	for example hiding customer names to freelancers.
#    4. Define Filter Categories:
#	Extract from the database the filter categories that
#	are available for a specific user.
#	For example "potential", "cost_itemd" and "partially paid" 
#	cost_items are not available for unprivileged users.
#    5. Generate SQL Query
#	Compose the SQL query based on filter criteria.
#	All possible columns are selected from the DB, leaving
#	the selection of the visible columns to the table columns,
#	defined in section 3.
#    6. Format Filter
#    7. Format the List Table Header
#    8. Format Result Data
#    9. Format Table Continuation
#   10. Join Everything Together

# ---------------------------------------------------------------
# 2. Defaults & Security
# ---------------------------------------------------------------

# User id already verified by filters
set user_id [ad_maybe_redirect_for_registration]
set page_title "Cost Items"
set context_bar [ad_context_bar $page_title]
set page_focus "im_header_form.keywords"
set return_url [im_url_with_query]
# Needed for im_view_columns, defined in intranet-views.tcl
set amp "&"
set cur_format "99,999.99"
set local_url "list"

if { [empty_string_p $how_many] || $how_many < 1 } {
    set how_many [ad_parameter -package_id [im_package_core_id] NumberResultsPerPage "" 50]
}
set end_idx [expr $start_idx + $how_many - 1]


# ---------------------------------------------------------------
# 3. Defined Table Fields
# ---------------------------------------------------------------

# Define the column headers and column contents that 
# we want to show:
#
set view_id [db_string get_view_id "select view_id from im_views where view_name=:view_name"]
set column_headers [list]
set column_vars [list]

set column_sql "
select
	column_name,
	column_render_tcl,
	visible_for
from
	im_view_columns
where
	view_id=:view_id
	and group_id is null
order by
	sort_order"

db_foreach column_list_sql $column_sql {
    if {"" == $visible_for || [eval $visible_for]} {
	lappend column_headers "$column_name"
	lappend column_vars "$column_render_tcl"
    }
}

# ---------------------------------------------------------------
# 4. Define Filter Categories
# ---------------------------------------------------------------

# status_types will be a list of pairs of (item_status_id, item_status)
set status_types [im_memoize_list select_item_status_types "
	select	0 as item_status_id,
	'All' as item_status
	from dual
UNION
	select item_status_id, item_status
	from im_cost_item_status
"]


# type_types will be a list of pairs of (item_type_id, item_type)
set type_types [im_memoize_list select_item_type_types "
        select  0 as item_type_id,
        'All' as item_type
        from dual
UNION
	select item_type_id, item_type
	from im_cost_item_type"]


# ---------------------------------------------------------------
# 5. Generate SQL Query
# ---------------------------------------------------------------

set criteria [list]
if { ![empty_string_p $item_status_id] && $item_status_id > 0 } {
    lappend criteria "ci.item_status_id=:item_status_id"
}
if { ![empty_string_p $item_type_id] && $item_type_id != 0 } {
    lappend criteria "ci.item_type_id in (
		select distinct	h.child_id
		from	im_category_hierarchy h
		where	(child_id=:item_type_id or parent_id=:item_type_id)
	)"
}
if {$customer_id} {
    lappend criteria "ci.customer_id=:customer_id"
}
if {$provider_id} {
    lappend criteria "ci.provider_id=:provider_id"
}
if { ![empty_string_p $letter] && [string compare $letter "ALL"] != 0 && [string compare $letter "SCROLL"] != 0 } {
    lappend criteria "im_first_letter_default_to_a(c.customer_name)=:letter"
}


# Get the list of user's companies for which he can see cost_items
set company_ids [db_list users_companies "
select
	customer_id
from
	acs_rels r,
	im_customers c
where
	r.object_id_two = :user_id
	and r.object_id_one = c.customer_id
"]

lappend company_ids 0

# Determine which cost_items the user can see.
# Normally only those of his/her company...
# Special users ("view_cost_items") don't need permissions.
set company_where ""
if {![im_permission $user_id view_cost_items]} { 
    set company_where "and (ci.customer_id in ([join $company_ids ","]) or ci.provider_id in ([join $company_ids ","]))"
}
ns_log Notice "/intranet-cost_items/index: company_where=$company_where"


set order_by_clause ""
switch $order_by {
    "Document #" { set order_by_clause "order by cost_item_nr" }
    "Preview" { set order_by_clause "order by cost_item_nr" }
    "Provider" { set order_by_clause "order by provider_name" }
    "Client" { set order_by_clause "order by customer_name" }
    "Due Date" { set order_by_clause "order by (ci.effective_date+ci.payment_days)" }
    "Paid" { set order_by_clause "order by pa.payment_amount" }
    "Status" { set order_by_clause "order by item_status_id" }
    "Type" { set order_by_clause "order by item_type" }
}

set where_clause [join $criteria " and\n            "]
if { ![empty_string_p $where_clause] } {
    set where_clause " and $where_clause"
}

# -----------------------------------------------------------------
# Define extra SQL for payments
# -----------------------------------------------------------------

#set payment_amount ""
#set payment_currency ""

set extra_select ""
set extra_from ""
set extra_where ""

if { [db_table_exists im_payments] } {
    append extra_select ", pa.payment_amount, pa.payment_currency\n"
    append extra_from ", 
	(select
		sum(amount) as payment_amount, 
		max(currency) as payment_currency,
		item_id 
	 from im_payments
	 group by item_id
	) pa\n"
    append extra_where "and ci.item_id=pa.item_id(+)\n"
}

# -----------------------------------------------------------------
# Main SQL
# -----------------------------------------------------------------

set sql "
select
        ci.*,
	ci.amount as amount_formatted,
	ci.effective_date + ci.payment_days as due_date_calculated,
        c.customer_name,
        c.customer_path as customer_short_name,
	p.customer_name as provider_name,
	p.customer_path as provider_short_name,
        im_category_from_id(ci.item_status_id) as item_status,
        im_category_from_id(ci.item_type_id) as item_type,
	sysdate - (ci.effective_date + ci.payment_days) as overdue
	$extra_select
from
        im_cost_items ci,
        im_customers c,
        im_customers p
	$extra_from
where
        ci.customer_id=c.customer_id(+)
        and ci.provider_id=p.customer_id(+)
	$company_where
        $where_clause
	$extra_where
$order_by_clause
"

# ---------------------------------------------------------------
# 5a. Limit the SQL query to MAX rows and provide << and >>
# ---------------------------------------------------------------

# Limit the search results to N data sets only
# to be able to manage large sites
#
if {[string compare $letter "ALL"]} {
    # Set these limits to negative values to deactivate them
    set total_in_limited -1
    set how_many -1
    set selection "$sql"
} else {
    set limited_query [im_select_row_range $sql $start_idx $end_idx]
    # We can't get around counting in advance if we want to be able to 
    # sort inside the table on the page for only those users in the 
    # query results
    set total_in_limited [db_string cost_items_total_in_limited "
	select count(*) 
        from im_cost_items p
        where 1=1 $where_clause"]

    set selection "select z.* from ($limited_query) z $order_by_clause"
}	

# ---------------------------------------------------------------
# 6a. Format the Filter: Get the admin menu
# ---------------------------------------------------------------

set new_document_menu ""
set parent_menu_label ""

if {"" != $parent_menu_label} {
    set parent_menu_sql "select menu_id from im_menus where label=:parent_menu_label"
    set parent_menu_id [db_string parent_admin_menu $parent_menu_sql -default ""]

    set menu_select_sql "
        select  m.*
        from    im_menus m
        where   parent_menu_id = :parent_menu_id
                and acs_permission.permission_p(m.menu_id, :user_id, 'read') = 't'
        order by sort_order"

    # Start formatting the menu bar
    set new_document_menu ""
    set ctr 0
    db_foreach menu_select $menu_select_sql {
	
	ns_log Notice "im_sub_navbar: menu_name='$name'"
	append new_document_menu "<li><a href=\"$url\">$name</a></li>\n"
    }
}

# ---------------------------------------------------------------
# 6. Format the Filter
# ---------------------------------------------------------------

# Note that we use a nested table because im_slider might
# return a table with a form in it (if there are too many
# options
set filter_html "

<table>
<tr valign=top>
  <td valign=top>

	<form method=get action='/intranet-cost_items/list'>
	[export_form_vars start_idx order_by how_many view_name include_subcost_items_p letter]
	<table border=0 cellpadding=1 cellspacing=1>
	  <tr> 
	    <td colspan='2' class=rowtitle align=center>
	      Filter Documents
	    </td>
	  </tr>
	  <tr>
	    <td>Document Status:</td>
	    <td>
              [im_select item_status_id $status_types ""]
            </td>
	  </tr>
	  <tr>
	    <td>Document Type:</td>
	    <td>
              [im_select item_type_id $type_types ""]
              <input type=submit value=Go name=submit>
            </td>
	  </tr>
	</table>
	</form>

  </td>
  <td valign=top>&nbsp;</td>
  <td valign=top>

	<table border=0 cellpadding=1 cellspacing=1>
	  <tr> 
	    <td colspan='2' class=rowtitle align=center>
	      New Customer Documents
	    </td>
	  </tr>
	  <tr>
	    <td colspan=2 valign=top>
	      <ul>
		$new_document_menu
	      </ul>
            </td>
	  </tr>
	</table>
	
  </td>
</tr>
</table>
"

# ---------------------------------------------------------------
# 7. Format the List Table Header
# ---------------------------------------------------------------

# Set up colspan to be the number of headers + 1 for the # column
set colspan [expr [llength $column_headers] + 1]

set table_header_html ""
#<tr>
#  <td align=center valign=top colspan=$colspan><font size=-1>
#    [im_groups_alpha_bar [im_cost_item_group_id] $letter "start_idx"]</font>
#  </td>
#</tr>"

# Format the header names with links that modify the
# sort order of the SQL query.
#
set url "$local_url?"
set query_string [export_ns_set_vars url [list order_by]]
if { ![empty_string_p $query_string] } {
    append url "$query_string&"
}

append table_header_html "<tr>\n"
foreach col $column_headers {
    if { [string compare $order_by $col] == 0 } {
	append table_header_html "  <td class=rowtitle>$col</td>\n"
    } else {
	append table_header_html "  <td class=rowtitle><a href=\"${url}order_by=[ns_urlencode $col]\">$col</a></td>\n"
    }
}
append table_header_html "</tr>\n"


# ---------------------------------------------------------------
# 8. Format the Result Data
# ---------------------------------------------------------------

set table_body_html ""
set bgcolor(0) " class=roweven "
set bgcolor(1) " class=rowodd "
set ctr 0
set idx $start_idx
db_foreach cost_items_info_query $selection {
    set url [im_maybe_prepend_http $url]
    if { [empty_string_p $url] } {
	set url_string "&nbsp;"
    } else {
	set url_string "<a href=\"$url\">$url</a>"
    }

    # Append together a line of data based on the "column_vars" parameter list
    append table_body_html "<tr$bgcolor([expr $ctr % 2])>\n"
    foreach column_var $column_vars {
	append table_body_html "\t<td valign=top>"
	set cmd "append table_body_html $column_var"
	eval $cmd
	append table_body_html "</td>\n"
    }
    append table_body_html "</tr>\n"

    incr ctr
    if { $how_many > 0 && $ctr >= $how_many } {
	break
    }
    incr idx
}

# Show a reasonable message when there are no result rows:
if { [empty_string_p $table_body_html] } {
    set table_body_html "
        <tr><td colspan=$colspan><ul><li><b> 
        There are currently no cost_items matching the selected criteria
        </b></ul></td></tr>"
}

if { $ctr == $how_many && $end_idx < $total_in_limited } {
    # This means that there are rows that we decided not to return
    # Include a link to go to the next page
    set next_start_idx [expr $end_idx + 1]
    set next_page_url "$local_url?start_idx=$next_start_idx&[export_ns_set_vars url [list start_idx]]"
} else {
    set next_page_url ""
}

if { $start_idx > 1 } {
    # This means we didn't start with the first row - there is
    # at least 1 previous row. add a previous page link
    set previous_start_idx [expr $start_idx - $how_many]
    if { $previous_start_idx < 1 } {
	set previous_start_idx 1
    }
    set previous_page_url "$local_url?start_idx=$previous_start_idx&[export_ns_set_vars url [list start_idx]]"
} else {
    set previous_page_url ""
}

# ---------------------------------------------------------------
# 9. Format Table Continuation
# ---------------------------------------------------------------

# Check if there are rows that we decided not to return
# => include a link to go to the next page 
#
if {$ctr==$how_many && $total_in_limited > 0 && $end_idx < $total_in_limited} {
    set next_start_idx [expr $end_idx + 1]
    set next_page "<a href=$local_url?start_idx=$next_start_idx&[export_ns_set_vars url [list start_idx]]>Next Page</a>"
} else {
    set next_page ""
}

# Check if this is the continuation of a table (we didn't start with the 
# first row - there is at least 1 previous row.
# => add a previous page link
#
if { $start_idx > 1 } {
    set previous_start_idx [expr $start_idx - $how_many]
    if { $previous_start_idx < 1 } {
	set previous_start_idx 1
    }
    set previous_page "<a href=$local_url?start_idx=$previous_start_idx&[export_ns_set_vars url [list start_idx]]>Previous Page</a>"
} else {
    set previous_page ""
}

set table_continuation_html "
<tr>
  <td align=center colspan=$colspan>
    [im_maybe_insert_link $previous_page $next_page]
  </td>
</tr>"

set button_html "
<tr>
  <td colspan=[expr $colspan - 3]></td>
  <td align=center>
    <input type=submit name=submit value='Save'>
  </td>
  <td align=center>
    <input type=submit name=submit value='Del'>
  </td>
</tr>"

# ---------------------------------------------------------------
# 10. Join all parts together
# ---------------------------------------------------------------

set page_body "
$filter_html
[im_cost_items_navbar $letter "/intranet-cost/list" $next_page_url $previous_page_url [list item_status_id item_type_id customer_id start_idx order_by how_many view_name letter]]

<form action=cost_item-action method=POST>
[export_form_vars customer_id item_id return_url]
  <table width=100% cellpadding=2 cellspacing=2 border=0>
    $table_header_html
    $table_body_html
    $table_continuation_html
    $button_html
  </table>
</form>

"

db_release_unused_handles

doc_return  200 text/html [im_return_template]
