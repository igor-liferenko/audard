
	<?php
/*   <HTML>
    <BODY> */
 
 	// get current user
	$user = $_SERVER["PHP_AUTH_USER"];
	
	// get current file name (http://codesnippets.joyent.com/posts/show/1772)
    $currentFile = $_SERVER["SCRIPT_NAME"];
    $parts = Explode('/', $currentFile);
    $currentFile = $parts[count($parts) - 1];
	$curdir = dirname($_SERVER["SCRIPT_NAME"]); ///~sd/faq - not full path
	$curpath = shell_exec ("pwd -L");
	$curpath = substr($curpath, 0, -1); //remove last space or \n character
	//echo $curdir . " --- " . $curpath . " --- " . $currentFile; 
	
	$dbg = isset($_REQUEST["d"]); //just add &d to query string for "debug mode"
	
 	if (isset($_REQUEST["f"]))		
 	{

	// filename  of wiki file - for now local only to this folder
	$fname = $_REQUEST["f"]; 
	
	// arguments of wiki2html:
	$base_href = "-b /"; //Used for regular wikilinks. Sets the <base href="..."> tag.   Default is http://localhost/
	$image_location = "-i ."; // "-i img/"; //Used for [[image:]] links. Default is http://localhost/images/
	$title = "-t $fname";
	
	// get file contents
	// however: "If FILE is unspecified, input is from stdin"
	// so we don't need to read it here
	//$rawwiki = file_get_contents($fname);
 
 	// pwd -L -P from apache: /dsk/md1/group/www/homepages/staff/sd/aau_projects/wolaaub
 	// pwd -P ssh: /dsk/nfs/ernestine_dsk_md1/group/www/homepages/staff/sd/aau_projects/wolaaub
	// pwd -L ssh: /nfs/staff/sd/sdweb/aau_projects/wolaaub
	
 	// compose the command with arguments and whole path to the script
	//$scriptpath = "/dsk/md1/group/www/homepages/staff/sd/aau_projects/wolaaub/";
	$scriptpath = $curpath;
	$scriptname = "wiki2html"; //binary unix executable actually
	$cmd = "$scriptpath/$scriptname $base_href $image_location $title $fname";
	
	//$report = shell_exec ($cmd);
	if ($dbg) echo "<b>Command: </b> " . $cmd . "<br>\r\n";
	if ($dbg) echo "<b>Response: </b> <pre>";
	
	// these commands buffer the stdout of the command before displaying it. 
	//echo shell_exec ($cmd);
	//passthru($cmd);
	
	// call cmd, and display output in "realtime" 
	$pipe = popen("$cmd" , 'r');
	if (!$pipe) {
		print "pipe failed.";
	}
	else
	{
		while(!feof($pipe)) {
			// read only one byte at a time from stdout and
			// flush it immediately to webpage, to have a "realtime"
			// perception of say ping... 
			echo fread($pipe, 1024); //was 2048 and 64...
			flush();
		}  
	}
	pclose($pipe);
    
	if ($dbg) echo "</pre><br>\r\n";
	}

/*         <h1>AAU Balerup</h1>
    </BODY>
</HTML> */

 ?>


