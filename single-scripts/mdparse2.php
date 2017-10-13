<?php

# mdparse2.php
# copyleft sdaau, 2011
# additions to use directly the Markdown parser via this single file
# callable online with: mdparse2.php?f=test.md
#
# test with php-cli:
# QUERY_STRING="f=test.md" php mdparse2.php

// errors:
//~ ini_set('display_errors', '1');


// ## MAIN ## /////////

# markdown.php - in http://michelf.com/docs/projets/php-markdown-1.0.1n.zip
# place appropriately
include_once "markdown.php";

//http://people.w3.org/~dom/archives/2004/07/testing-php-pages-with-query_string/
if (empty($_GET)) {
  //~ parse_str($_ENV['QUERY_STRING'],$_GET); //nowork
  parse_str(getenv('QUERY_STRING'),$_GET); //OK
}

//~ echo print_r($_GET);

$fname=$_GET['f'];


if (!empty($fname)) {
  if (file_exists($fname)) {
    //echo "Exists\n";

    $my_text = file_get_contents('./'.$fname);

    $my_html = Markdown($my_text);

    // for unicode output: (http://stackoverflow.com/questions/713293)
    header('Content-Type: text/html; charset=utf-8');

    echo "<html>\n<head>\n<title>$fname</title>\n</head>\n<body>\n";
    echo "$my_html";
    echo "\n</body>\n</html>\n";
  } else {
    echo "LoL\n";
  }
}


?>