#!/usr/bin/php
<?php
require ('/opt/configs/config.php');
chdir(__DIR__);

$mysqli = new mysqli(DB_HOST, DB_USER, DB_PASSWORD, DB_NAME);

$query = "
select sql_stmt
from (
  select p.db, p.name, p.type, 1 as intord, p.character_set_client,
    concat('DROP ',p.type, ' IF EXISTS ',p.name,';') as sql_stmt
  from mysql.proc p
  union all
  select p.db, p.name, p.type, 2 as intord, p.character_set_client,
    'delimiter $$' as sql_stmt
  from mysql.proc p
  union all
  select p.db, p.name, p.type, 3 as intord, p.character_set_client,
    concat('CREATE ',
      p.type,
      ' ',p.name,
      '(',convert(p.param_list USING utf8),') ',
      case
        when length(p.returns) > 1
        then concat(' RETURNS ', convert(p.returns USING utf8))
        else ''
      end, ' \n',
      case
        when p.is_deterministic = 'YES' then '\tDETERMINISTIC\n'
        else ''
      end,
      case
        when p.language = 'SQL' THEN ''
        else concat('\tLANGUAGE ',p.language, '\n')
      end,
      case
        when p.sql_data_access = 'CONTAINS_SQL' THEN ''
        when p.sql_data_access = 'NO_SQL' THEN '\tNO SQL\n'
        when p.sql_data_access = 'READS_SQL_DATA' THEN '\tREADS SQL DATA\n'
        when p.sql_data_access = 'MODIFIES_SQL_DATA' THEN '\tMODIFIES SQL DATA\n'
        else concat('\t',replace(p.sql_data_access,'_', ' '), '\n')
      end,
      case when p.security_type <> 'DEFINER'
        then concat('\tSQL SECURITY ', p.security_type, '\n')
        else ''
      end,
      case when p.comment <> ''
        then concat('\tCOMMENT ''',
          replace(replace(p.comment,'''',''''''),'\n','\\n')
          ,'''')
        else ''
      end, '\n',
      convert(p.body USING utf8),
      '$$'
    ) as sql_stmt
  from mysql.proc p
  union all
  select p.db, p.name, p.type, 4 as intord, p.character_set_client,
    'delimiter ;' as sql_stmt
  from mysql.proc p
  union all
  select p.db, p.name, p.type, 0 as intord, p.character_set_client,
  p.name as sql_stmt
  from mysql.proc p

) sql_stmts
where db = 'eddb'
and type = 'procedure'
order by db, name, type, intord;";

$counter = 0;
if ($result = $mysqli->query($query)) {
    while ($data = $result->fetch_assoc()) {
        if ($counter == 0) {
            $contents = "";
            $tfn = __DIR__ . "/" . $data['sql_stmt'] . ".sql";
        } else {
            $contents .= $data['sql_stmt'] . "\n\n\n";
        }
        if ($counter == 4) {
            $counter = 0;
            $fp = fopen($tfn, 'w');
            fwrite($fp, $contents);
            fclose($fp);
        } else {
            $counter++;
        }
    }
}

system("cat *.sql > AllCommands.out");
system("git add .");
system("git commit -m 'Automated Update'");
system("git push");
