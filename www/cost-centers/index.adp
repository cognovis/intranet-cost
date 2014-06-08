<master src="/packages/intranet-core/www/admin/master">
<property name="title">@page_title;noquote@</property>
<property name="main_navbar_label">admin</property>
<property name="admin_navbar_label">admin_cost_centers</property>
<property name="left_navbar">@left_navbar_html;noquote@</property>

<h1>@page_title@</h1>

@help_txt;noquote@
<br><br>
<form action=cost-center-action method=post>
      <%= [export_form_vars return_url] %>
      <table width="100%">
      @table_header;noquote@
      @table;noquote@
      </table>
</form>

