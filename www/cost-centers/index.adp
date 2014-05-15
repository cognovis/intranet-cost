<master src="/packages/intranet-core/www/admin/master">
<property name="title">@page_title;noquote@</property>
<property name="main_navbar_label">admin</property>
<property name="admin_navbar_label">admin_cost_centers</property>
<property name="left_navbar">@left_navbar_html;noquote@</property>

<h1>@page_title@</h1>

<%=[lang::message::lookup "" intranet-cost.Cost_Center_help "To show CC in right order please set 'Cost Center Code' accordingly. For additional help please use the 'Context Help' that is provided for this page."]%>
<br><br>
<form action=cost-center-action method=post>
      <%= [export_form_vars return_url] %>
      <table width="100%">
      @table_header;noquote@
      @table;noquote@
      </table>
</form>

