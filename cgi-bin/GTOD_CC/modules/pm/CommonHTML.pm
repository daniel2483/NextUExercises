#!/opt/perl/bin/perl

use strict;
use Sys::Hostname;
use File::Basename;
use File::Temp "tempfile";
use Getopt::Std;
use FileHandle;
use Data::Dumper;
use CGI qw(:standard);
use Excel::Writer::XLSX;
use URI::Escape;
use HTML::Entities;

my $green = "green";
my $red = "red";
my $amber = "amber";
my $grey = "";
my $orange ="orange";
my $cyan = "";
my $cgreen="green";
my $lgrey="";
my $info="";
my $info2="";

my @th_info = ();

sub validate_cgi_parameters
{

	my ($parm_list) = @_;

	my @list = ('allowed_parameter');
	my %cache = load_cache(\@list);
	my %allowed_parameter = %{$cache{allowed_parameter}};
	my %cgi_param;

	# Get my CGI parameters from the QUERY_STRING and put them in a hash for easy reference...
	my $e = $ENV{"QUERY_STRING"};
	$e=~s/\?/\&/;
	my @query_string = split("&",$e);

	my @bad_params;

	foreach my $q (@query_string) {
			my ($a,$b) = (split(/\=/, $q))[0,1];
			next if ($a =~ /oa|embed|behaviour|undefined/i);
			$cgi_param{$a} = uri_unescape($b) ;
	}

	# ITerate through the ones we are interested in - and check their contents are in the dictionary...
	foreach my $a (@{$parm_list}) {

		$b = $cgi_param{$a};
		next if ($b eq "");  #no value sent...which is ok...

		# Stop people from injecting java script into CGI Parameters....
		# this would get caught in the following step - but added it anyway...
		if ($b =~ /\<script\>|\<\/script\>/i) {
			push @bad_params, $a;
		}


		#allowed parameters is a big bucket of allowable parameters - includes customers, capabilities, technologies, report_types,.....
		#allowed_parameter is created by collectors/get_allowed_parameter.pl
		#this stops injection of rubbish into CGI parameters
		#all l1/l2/l3 scripts check their parameters against this...
		#print "A=$a, B=$b<br>";
		if ($a =~ /^day$/i and $b=~/^\d+$/) {
			#	print "$a = $b is ok<br>";
		} elsif ($a =~ /^mapping|tool_name|std_event|fqdn|flow|sub|cap$/i) {
		#	print "$a = $b is ok<br>";
		} elsif ($a =~ /request/i and $b =~ /^\w{2,6}\d+|^\d+$/i) {
		#	print "$a = $b is ok<br>";
		} elsif ($a =~ /query_type/i and $b =~ /(enrolled|etp|not_enrolled)$/i) {
		#	print "$a = $b is ok<br>";
		} elsif ($a =~ /tool_name/i and $b =~ /^.*?\_monitoring$/i) {
		#	print "$a = $b is ok<br>";
		} elsif ($a =~ /id/i and $b =~ /^\d+$/) {
		#	print "$a = $b is ok<br>";
		} elsif ($a =~ /pattern/i) {
		#	print "$a = $b is ok<br>";
		} elsif ($a =~ /month|period/ and $b =~ /^\S{3}\-\d{2}$/) {
		#	print "$a = $b is ok<br>";
		} elsif ($a =~ /^selected_month$|^week$/ and $b =~ /^\d{4}\-\d{2}\-\d{2}$/) {
		#	print "$a = $b is ok<br>";
		} elsif ($a =~ /^month$/ and $b =~ /^\d+$/) {
		#	print "$a = $b is ok<br>";
		} elsif ($a =~ /tick/i and $b=~/^\d+$/) {
		#	print "$a = $b is ok<br>";
		} elsif ($a =~ /inc_id/ and $b =~ /(\w{0,}\-im\d{5,}|\w{0,}inc\d{5,})/i) {
		# print "$a = $b is ok<br>";
		} elsif ($a =~ /sr_id/ and $b =~ /(\w{0,}\-sd\d{5,})/i) {
		# print "$a = $b is ok<br>";
		} elsif (not defined($allowed_parameter{lc($b)})) {
		#	print "$a has a bad value of $b<br>";
			push @bad_params, $a;
		} else {
		#	print "$a = $b is ok<br>";
		}

	}

	return \@bad_params;
}

sub set_formats
{
	my ($workbook, $xls_attr) = @_;

	$xls_attr->{GRAY_FORMAT} = $workbook->add_format( bold => 1, border_color => 'white', bg_color =>'black',	pattern => 1,	border => 1,  valign => 'vcenter', align  => 'center');
	$xls_attr->{GRAY_FORMAT}->set_color( 'white' );


	$xls_attr->{RED_FORMAT} = $workbook->add_format(		bg_color =>'red',	pattern => 1,	border => 1);
	$xls_attr->{GREEN_FORMAT} = $workbook->add_format(	bg_color =>'green',	pattern => 1,	border => 1);
	$xls_attr->{ORANGE_FORMAT} = $workbook->add_format(	bg_color =>'orange',	pattern => 1,	border => 1);
	$xls_attr->{WHITE_FORMAT} = $workbook->add_format(	bg_color =>'white',	pattern => 1,	border => 4);
	$xls_attr->{ALT_WHITE_FORMAT} = $workbook->add_format(	bg_color =>'#F6F6F6',	pattern => 1,	border => 4);
	$xls_attr->{WHITE_FORMAT} = $workbook->add_format(	bg_color =>'white',	pattern => 1,	border => 4);
	$xls_attr->{ALT_WHITE_FORMAT} = $workbook->add_format(	bg_color =>'#F6F6F6',	pattern => 1,	border => 4);


	$xls_attr->{PERC_RED_FORMAT} = $workbook->add_format(		num_format=> '0.00%', bg_color =>'red',	pattern => 1,	border => 1);
	$xls_attr->{PERC_GREEN_FORMAT} = $workbook->add_format(	num_format=> '0.00%', bg_color =>'green',	pattern => 1,	border => 1);
	$xls_attr->{PERC_ORANGE_FORMAT} = $workbook->add_format(	num_format=> '0.00%', bg_color =>'orange',	pattern => 1,	border => 1);
	$xls_attr->{PERC_WHITE_FORMAT} = $workbook->add_format(	num_format=> '0.00%', bg_color =>'white',	pattern => 1,	border => 4);
	$xls_attr->{PERC_ALT_WHITE_FORMAT} = $workbook->add_format(	num_format=> '0.00%', bg_color =>'#F6F6F6',	pattern => 1,	border => 4);
	$xls_attr->{PERC_WHITE_FORMAT} = $workbook->add_format(	num_format=> '0.00%', bg_color =>'white',	pattern => 1,	border => 4);
	$xls_attr->{PERC_ALT_WHITE_FORMAT} = $workbook->add_format(	num_format=> '0.00%', bg_color =>'#F6F6F6',	pattern => 1,	border => 4);

	$xls_attr->{DOLLAR_RED_FORMAT} = $workbook->add_format(		num_format=> '$#,##0', bg_color =>'red',	pattern => 1,	border => 1);
	$xls_attr->{DOLLAR_GREEN_FORMAT} = $workbook->add_format(	num_format=> '$#,##0', bg_color =>'green',	pattern => 1,	border => 1);
	$xls_attr->{DOLLAR_ORANGE_FORMAT} = $workbook->add_format(	num_format=> '$#,##0', bg_color =>'orange',	pattern => 1,	border => 1);
	$xls_attr->{DOLLAR_WHITE_FORMAT} = $workbook->add_format(	num_format=> '$#,##0', bg_color =>'white',	pattern => 1,	border => 4);
	$xls_attr->{DOLLAR_ALT_WHITE_FORMAT} = $workbook->add_format(	num_format=> '$#,##0', bg_color =>'#F6F6F6',	pattern => 1,	border => 4);
	$xls_attr->{DOLLAR_WHITE_FORMAT} = $workbook->add_format(	num_format=> '$#,##0', bg_color =>'white',	pattern => 1,	border => 4);
	$xls_attr->{DOLLAR_ALT_WHITE_FORMAT} = $workbook->add_format(	num_format=> '$#,##0', bg_color =>'#F6F6F6',	pattern => 1,	border => 4);


	$xls_attr->{XLS_X} = 0;
	$xls_attr->{XLS_Y} = 0;

	$xls_attr->{WORKSHEET}->add_write_handler(qr[\w], \&store_string_widths);
}

sub finish_formats
{
	my ($workbook, $xls_attr) = @_;

	my $worksheet = $xls_attr->{WORKSHEET};

	# Run the autofit after you have finished writing strings to the workbook.
	autofit_columns($xls_attr->{WORKSHEET});
	$worksheet->autofilter( $xls_attr->{XLS_Y_MIN} - 1, $xls_attr->{XLS_X_MIN} - 1, $xls_attr->{XLS_Y_MAX} , $xls_attr->{XLS_X_MAX} - 1 );

	print "Content-Disposition: attachment;\n";
}

sub autofit_columns {

    my $worksheet = shift;
    my $col       = 0;

    for my $width (@{$worksheet->{__col_widths}}) {

        $worksheet->set_column($col, $col, $width) if $width;
        $col++;
    }
}


###############################################################################
#
# The following function is a callback that was added via add_write_handler()
# above. It modifies the write() function so that it stores the maximum
# unwrapped width of a string in a column.
#
sub store_string_widths {

    my $worksheet = shift;
    my $col       = $_[1];
    my $token     = $_[2];

    # Ignore some tokens that we aren't interested in.
    return if not defined $token;       # Ignore undefs.
    return if $token eq '';             # Ignore blank cells.
    return if ref $token eq 'ARRAY';    # Ignore array refs.
    return if $token =~ /^=/;           # Ignore formula

    # Ignore numbers
    return if $token =~ /^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/;

    # Ignore various internal and external hyperlinks. In a real scenario
    # you may wish to track the length of the optional strings used with
    # urls.
    return if $token =~ m{^[fh]tt?ps?://};
    return if $token =~ m{^mailto:};
    return if $token =~ m{^(?:in|ex)ternal:};


    # We store the string width as data in the Worksheet object. We use
    # a double underscore key name to avoid conflicts with future names.
    #
    my $old_width    = $worksheet->{__col_widths}->[$col];
    my $string_width = string_width($token);

    if (not defined $old_width or $string_width > $old_width) {
        # You may wish to set a minimum column width as follows.
        #return undef if $string_width < 10;

        $worksheet->{__col_widths}->[$col] = $string_width;
    }


    # Return control to write();
    return undef;
}


###############################################################################
#
# Very simple conversion between string length and string width for Arial 10.
# See below for a more sophisticated method.
#
sub string_width {

    return 1.2 * length $_[0];
}

sub tableHeader
{
   my ($l,$color) = @_;
   if (!$color) { $color = 'FFFFFF'; }
   if ($l =~ /unknown/i) {$color=$grey;}
   #if ($l =~ /^$/) {  $l = '&nbsp;'; }
   print "<th id=\"" .make_id($l) . "\">".  $l.'</th>'."\n";
}

sub tableHeaderColumn
{
   my ($msg,$color,$column,$size,$row) = @_;
   if (!$color) { $color = 'FFFFFF'; }
   if (!$column) { $column = 1; }
   #if ($msg =~ /^$/) { $msg = '&nbsp;';}
   if (!$row) { $row =1; }
   if (!$size) {
   	 print '<th id="'. make_id($msg) .'" colspan="' . "$column\">" .  "$msg" . '</th>' . "\n";
 	 } else {
 	 	 print '<th id="' . make_id($msg) . '" colspan="' . "$column\" rowspan=\"$row\">" . "$msg" . '</th>' . "\n";
 	 }
}


sub tableHeaderColumn_xls
{
   my ($msg, $cell_attr, $xls_attr,$comment) = @_;
   my $color = $cell_attr->{CELL_COLOR} || 'FFFFFF';
   my $column = $cell_attr->{COL_SPAN} || 1;
   my $row = $cell_attr->{ROW_SPAN} || 1;
   my $size = $cell_attr->{SIZE};
   my $class = $cell_attr->{CLASS_NAME};
	 my $table_id= $cell_attr->{TABLE_ID};	 
   my ($hvalue);
   if ($class) { $hvalue = "class\=\"$class\""; }

   my $worksheet = $xls_attr->{WORKSHEET};
	 if (defined($xls_attr->{API})) {
	 	## API JSON DATA
	 	$cell_attr->{VALUE}=$msg;
	 	$cell_attr->{ROW_SPAN}=$row ||1;
	 	$cell_attr->{COL_SPAN}=$column ||1;
	 	$cell_attr->{ROW_NUMBER} = $xls_attr->{XLS_Y};	 	
	 	#$cell_attr->{CELL_COLOR}=$color ||'FFFFFF';
	 	#$cell_attr->{SIZE}=$size;
	 	#$cell_attr->{CLASS_NAME}=$class ;
	 	if(defined($table_id)){
	 		$xls_attr->{MULTI_TABLE}=1;
	 		$xls_attr->{$table_id}{XLS_X}=$xls_attr->{XLS_X};
	 		$xls_attr->{$table_id}{XLS_Y}=$xls_attr->{XLS_Y};
	 		if (ref($xls_attr->{$table_id}{ROWSPANS_COLUMN}) =~ /hash/i) {
   	 		while($xls_attr->{$table_id}{ROWSPANS_COLUMN}->{$xls_attr->{$table_id}{XLS_X}} > $xls_attr->{$table_id}{XLS_Y}) {
	   	 		$xls_attr->{$table_id}{XLS_X}++;
  	 		}
  	 	}
	 		for (my $i=0; $i < $column; $i++) {
   	 		$xls_attr->{$table_id}{ROWSPANS_COLUMN}->{$xls_attr->{$table_id}{XLS_X} + $i} = $xls_attr->{$table_id}{XLS_Y}+$row;
   	 	}
   	 	$xls_attr->{$table_id}{XLS_X}+=$column;	 		
	 		push @{$xls_attr->{$table_id}{TABLEHEADER}}, $cell_attr;
	 	}else{
	 		if (ref($xls_attr->{ROWSPANS_COLUMN}) =~ /hash/i) {
   	 		while($xls_attr->{ROWSPANS_COLUMN}->{$xls_attr->{XLS_X}} > $xls_attr->{XLS_Y}) {
	   	 		$xls_attr->{XLS_X}++;
  	 		}
  	 	}
	 		for (my $i=0; $i < $column; $i++) {
   	 		$xls_attr->{ROWSPANS_COLUMN}->{$xls_attr->{XLS_X} + $i} = $xls_attr->{XLS_Y}+$row;
   	 	}
   	 	$xls_attr->{XLS_X}+=$column;	 		
	 		push @{$xls_attr->{TABLEHEADER}}, $cell_attr;
	 	}
	 }elsif (not defined($xls_attr->{WORKSHEET})) {
   	# create HTML

   	if ($hvalue ne "") {
  	 		print "<th id=\"" . make_id($msg) . "\" $hvalue colspan\=\"$column\" rowspan=\"$row\" >" . "$msg" . '</th>';
  	 } else {
   		print "<th id=\"" . make_id($msg) . "\" colspan\=\"$column\" rowspan=\"$row\">" . "$msg" . '</th>';
   	}
 	 } else {
 	 	 #create EXCEL
 	 	 if (ref($xls_attr->{ROWSPANS_COLUMN}) =~ /hash/i) {
   	 	while($xls_attr->{ROWSPANS_COLUMN}->{$xls_attr->{XLS_X}} > $xls_attr->{XLS_Y}) {
	   	 	$xls_attr->{XLS_X}++;
  	 	}
  	 }

   	 $msg =~ s/<BR>/ /ig;
   	 $msg =~ s|<.+?>||g;
   	 $msg = uc($msg);

   	 if ($row > 1 or $column > 1) {
   	 	$worksheet->merge_range($xls_attr->{XLS_Y}, $xls_attr->{XLS_X}, $xls_attr->{XLS_Y} + $row - 1, $xls_attr->{XLS_X} + $column - 1, $msg, $xls_attr->{GRAY_FORMAT});
   	 } else {
   	 	$worksheet->write($xls_attr->{XLS_Y},$xls_attr->{XLS_X},$msg,  $xls_attr->{GRAY_FORMAT});
   	 }
   	 for (my $i=0; $i < $column; $i++) {
   	 		$xls_attr->{ROWSPANS_COLUMN}->{$xls_attr->{XLS_X} + $i} = $xls_attr->{XLS_Y}+$row;
   	 }
   	 $xls_attr->{XLS_X}+=$column;
 	}
 	
 	### This is added so that there is a XLS_X_MAX value even if there is no Table Data 
 	### so that the API returns enough JSON so that the Table will at least print the headers and not Error out.
 	if (defined($table_id)) {		
		# Store the largest X,Y co-ordinates of the table (bottom corner)
		if ($xls_attr->{$table_id}{XLS_X} > $xls_attr->{$table_id}{XLS_X_MAX} or not defined($xls_attr->{$table_id}{XLS_X_MAX}))  {
			$xls_attr->{$table_id}{XLS_X_MAX} = $xls_attr->{$table_id}{XLS_X};
		}				
	}else{		
		# Store the largest X,Y co-ordinates of the table (bottom corner)
		if ($xls_attr->{XLS_X} > $xls_attr->{XLS_X_MAX} or not defined($xls_attr->{XLS_X_MAX}))  {
			$xls_attr->{XLS_X_MAX} = $xls_attr->{XLS_X};
		}				
	}
 	
}


sub tableHeaderColumn_Class
{
   my ($class,$msg,$color,$column,$size,$row) = @_;
   if (!$color) { $color = 'FFFFFF'; }
   if (!$column) { $column = 1; }
   #if ($msg =~ /^$/) { $msg = '&nbsp;';}
   if (!$row) { $row =1; }
   my ($hvalue,$fvalue);
   if ($class) { $hvalue = "class\=\"$class\""; }
   if ($size) { $fvalue = ""; }  
   else { $fvalue = ""; }
   if ($hvalue ne "") {
   		print "<th id=\"" . make_id($msg) . "\" $hvalue colspan\=\"$column\" rowspan=\"$row\" >" . "$msg" . '</th>';
   } else {
   		print "<th id=\"" . make_id($msg) . "\" colspan\=\"$column\" rowspan=\"$row\">" . "$msg" . '</th>';
   }
}

sub tableDataMultipleRow
{
   my ($msg,$row,$color,$size, $font_color) = @_;
   if (!$color) { $color = 'FFFFFF'; }
   if (!$font_color) { $font_color = 'black'; }
   #if ($msg =~ /^$/) { $msg = '&nbsp;';}

   if ($msg=~/^(<a href.*?\">)$/) { $msg = ''; }
   $msg =~ s/(\<a href.*?)\>/$1\>/g;

   if (!$row) { $row=1; }
   if ($size eq "") { $size = "3.9"; }
   if ($msg =~ /no data/i) { $msg =''; }
   if ($msg eq "") { $msg =''; }
   if ($color =~ /red|\#FF8080/i) {
   		print "<TD rowspan=\"$row\" class=\"alert alert-danger\">". $msg .'</TD>';
   } elsif ($color =~ /green|33FF66|CCFF99/i) {
   	  print "<TD rowspan=\"$row\" class=\"alert alert-success\">". $msg .'</TD>';
   } elsif ($color =~ /amber|yellow|orange|FFFF66|CC6633/i) {
   	  print "<TD rowspan=\"$row\" class=\"alert alert-warning\">". $msg .'</TD>';
   } else {
   	  print "<TD rowspan=\"$row\">". $msg .'</TD>';
   }
}


sub tableDataMultipleRow_xls
{
	my ($msg,$cell_attr,$xls_attr,$comment) = @_;


	my $row=$cell_attr->{ROW_SPAN} || 1;
	my $column=$cell_attr->{COL_SPAN} || 1;
	my $color = $cell_attr->{COLOR} || 'FFFFFF';
	my $text_color = $cell_attr->{TEXT_COLOR} || '000000';
	my $worksheet = $xls_attr->{WORKSHEET};
	my $class = $cell_attr->{CLASS_NAME};
	my $table_id= $cell_attr->{TABLE_ID};

	my $size;
	my $font_color;

	if ($msg=~/^(<a href.*?\">)$/) { $msg = ''; }
	$msg =~ s/(\<a href.*?)\>/$1\>/g;

	if (!$row) { $row=1; }
	if ($size eq "") { $size = "3.9"; }
	if ($msg =~ /no data/i) { $msg =''; }
	if ($msg eq "") { $msg =''; }

	if (defined($xls_attr->{API})) {
		## API JSON DATA
		$cell_attr->{VALUE}=$msg;
		$cell_attr->{ROW_SPAN}=$row ||1;
		$cell_attr->{COL_SPAN}=$column ||1;
		$cell_attr->{COLOR}=$color ||'FFFFFF';
		$cell_attr->{ROW_NUMBER} = $xls_attr->{XLS_Y};
		
		#$cell_attr->{TEXT_COLOR}=$text_color ||'000000';
		#$cell_attr->{CLASS_NAME}=$class ;
		if(defined($table_id)){
			$xls_attr->{MULTI_TABLE}=1;
			$xls_attr->{$table_id}{XLS_X}=$xls_attr->{XLS_X};
			$xls_attr->{$table_id}{XLS_Y}=$xls_attr->{XLS_Y};
			if (ref($xls_attr->{$table_id}{ROWSPANS_COLUMN}) =~ /hash/i) {
				while($xls_attr->{$table_id}{ROWSPANS_COLUMN}->{$xls_attr->{$table_id}{XLS_X}} > $xls_attr->{$table_id}{XLS_Y}) {
					$xls_attr->{$table_id}{XLS_X}++;
				}
			}
			for (my $i=0; $i < $column; $i++) {
				$xls_attr->{$table_id}{ROWSPANS_COLUMN}->{$xls_attr->{$table_id}{XLS_X} + $i} = $xls_attr->{$table_id}{XLS_Y}+$row;
			}	
			push @{$xls_attr->{$table_id}{TABLEDATA}}, $cell_attr;			
		}else{
			if (ref($xls_attr->{ROWSPANS_COLUMN}) =~ /hash/i) {
				while($xls_attr->{ROWSPANS_COLUMN}->{$xls_attr->{XLS_X}} > $xls_attr->{XLS_Y}) {
					$xls_attr->{XLS_X}++;
				}
			}
			for (my $i=0; $i < $column; $i++) {
				$xls_attr->{ROWSPANS_COLUMN}->{$xls_attr->{XLS_X} + $i} = $xls_attr->{XLS_Y}+$row;
			}	
			push @{$xls_attr->{TABLEDATA}}, $cell_attr;
		}
	}elsif (not defined($xls_attr->{WORKSHEET})) {
		# Print HTML
		if(defined($comment)) {
			print "<td class=\"tooltip-cell\" style=\"background-color:$color; color:$text_color;\" title=\"" . $comment . "\"><u> " . $msg . " </u></td>";
		} else {
			if ($color =~ /red|\#FF8080/i) {
				print "<TD colspan=\"$column\" rowspan=\"$row\" class=\"alert alert-danger $class\">". $msg .'</TD>';
			} elsif ($color =~ /green|33FF66|CCFF99/i) {
				print "<TD colspan=\"$column\" rowspan=\"$row\" class=\"alert alert-success $class\">". $msg .'</TD>';
			} elsif ($color =~ /amber|yellow|orange|FFFF66|CC6633/i) {
				print "<TD colspan=\"$column\" rowspan=\"$row\" class=\"alert alert-warning $class\">". $msg .'</TD>';
			} else {
				if ($class eq "") {
					print "<TD colspan=\"$column\" rowspan=\"$row\">". $msg .'</TD>';
				} else {
					print "<TD colspan=\"$column\" rowspan=\"$row\" class=\"$class\">". $msg .'</TD>';
				}
			}
		}

	} else {
		# Print to Excel
		if (ref($xls_attr->{ROWSPANS_COLUMN}) =~ /hash/i) {
			while($xls_attr->{ROWSPANS_COLUMN}->{$xls_attr->{XLS_X}} > $xls_attr->{XLS_Y}) {
				$xls_attr->{XLS_X}++;
			}
		}

		$msg =~ s/<BR>/ /ig;
		$msg =~ s|<.+?>||g;

		my $ff;
		if ($color =~ /red/i) {
			$ff = "RED_FORMAT";
		} elsif ($color=~/amber|orange/i) {
			$ff = "ORANGE_FORMAT";
		} elsif ($color =~ /green/i) {
			$ff = "GREEN_FORMAT";
		} elsif ($xls_attr->{XLS_X} % 2 == 0) {
			$ff = "WHITE_FORMAT";
		} else {
			$ff = "ALT_WHITE_FORMAT";
		}

		if ($msg=~/\%/ and $msg =~ /\d+/) {
			$ff = "PERC_${ff}";
			$msg=~s/\%//g;
			$msg=sprintf "%0.2f", ($msg / 100);
		}

		if ($msg=~/\$/ and $msg =~ /\d+/) {
			$ff = "DOLLAR_${ff}";
			$msg=~s/\$//g;
		}

		$msg = decode_entities($msg) if ($msg =~ m/&#/ );

		if ($row > 1 or $column > 1) {
			$worksheet->merge_range($xls_attr->{XLS_Y}, $xls_attr->{XLS_X}, $xls_attr->{XLS_Y} + $row - 1, $xls_attr->{XLS_X} + $column - 1, $msg, $xls_attr->{$ff});
		} else {
			$worksheet->write($xls_attr->{XLS_Y},$xls_attr->{XLS_X},$msg,  $xls_attr->{$ff});
			if(defined($comment)){
				$worksheet->write_comment($xls_attr->{XLS_Y},$xls_attr->{XLS_X},$comment);
			}
		}

		for (my $i=0; $i < $column; $i++) {
			$xls_attr->{ROWSPANS_COLUMN}->{$xls_attr->{XLS_X} + $i} = $xls_attr->{XLS_Y}+$row;
		}		
	}

	if (defined($table_id)) {
		$xls_attr->{$table_id}{XLS_X}+=$column;
		# Store the largest X,Y co-ordinates of the table (bottom corner)
		if ($xls_attr->{$table_id}{XLS_X} > $xls_attr->{$table_id}{XLS_X_MAX} or not defined($xls_attr->{$table_id}{XLS_X_MAX}))  {
			$xls_attr->{$table_id}{XLS_X_MAX} = $xls_attr->{$table_id}{XLS_X};
		}
		if ($xls_attr->{$table_id}{XLS_Y} > $xls_attr->{$table_id}{XLS_Y_MAX} or not defined($xls_attr->{$table_id}{XLS_Y_MAX})) {
			$xls_attr->{$table_id}{XLS_Y_MAX} = $xls_attr->{$table_id}{XLS_Y};
		}

		# Store the smallest  X,Y co-ordinates of the table (top left corner)
		if ($xls_attr->{$table_id}{XLS_X} < $xls_attr->{$table_id}{XLS_X_MIN} or not defined($xls_attr->{$table_id}{XLS_X_MIN})) {
			$xls_attr->{$table_id}{XLS_X_MIN} = $xls_attr->{$table_id}{XLS_X};
		}
		if ($xls_attr->{$table_id}{XLS_Y} < $xls_attr->{$table_id}{XLS_Y_MIN} or not defined($xls_attr->{$table_id}{XLS_Y_MIN})) {
			$xls_attr->{$table_id}{XLS_Y_MIN} = $xls_attr->{$table_id}{XLS_Y};
		}
	}else{
		$xls_attr->{XLS_X}+=$column;
		# Store the largest X,Y co-ordinates of the table (bottom corner)
		if ($xls_attr->{XLS_X} > $xls_attr->{XLS_X_MAX} or not defined($xls_attr->{XLS_X_MAX}))  {
			$xls_attr->{XLS_X_MAX} = $xls_attr->{XLS_X};
		}
		if ($xls_attr->{XLS_Y} > $xls_attr->{XLS_Y_MAX} or not defined($xls_attr->{XLS_Y_MAX})) {
			$xls_attr->{XLS_Y_MAX} = $xls_attr->{XLS_Y};
		}

		# Store the smallest  X,Y co-ordinates of the table (top left corner)
		if ($xls_attr->{XLS_X} < $xls_attr->{XLS_X_MIN} or not defined($xls_attr->{XLS_X_MIN})) {
			$xls_attr->{XLS_X_MIN} = $xls_attr->{XLS_X};
		}
		if ($xls_attr->{XLS_Y} < $xls_attr->{XLS_Y_MIN} or not defined($xls_attr->{XLS_Y_MIN})) {
			$xls_attr->{XLS_Y_MIN} = $xls_attr->{XLS_Y};
		}
	}
}


sub tableDataMultipleRowLeft
{
   my ($msg,$row,$color,$size, $font_color) = @_;
   if (!$color) { $color = 'FFFFFF'; }
   if (!$font_color) { $font_color = 'black'; }
   #if ($msg =~ /^$/) { $msg = '&nbsp;';}

   if ($msg=~/^(<a href.*?\">)$/) { $msg = ''; }
   $msg =~ s/(\<a href.*?)\>/$1 style=\"color:#3366cc\"\>/g;

   if (!$row) { $row=1; }
   if ($size eq "") { $size = "3.9"; }
   if ($msg =~ /no data/i) { $msg =''; }
   if ($msg eq "") { $msg =''; }
   if ($color =~ /red|\#FF8080/i) {
   		print "<TD rowspan=\"$row\" class=\"alert alert-danger\">". $msg .'</TD>';
   } elsif ($color =~ /green|33FF66|CCFF99/i) {
   	  print "<TD rowspan=\"$row\" class=\"alert alert-success\">". $msg .'</TD>';
   } elsif ($color =~ /amber|yellow|orange|FFFF66|CC6633/i) {
   	  print "<TD rowspan=\"$row\" class=\"alert alert-warning\">". $msg .'</TD>';
   } else {
   	  print "<TD rowspan=\"$row\">". $msg .'</TD>';
   }
}

sub tableDataMultipleColumn
{
   my ($msg,$row,$color,$column) = @_;
   if (!$color) { $color = 'FFFFFF'; }
   #if ($msg =~ /^$/) { $msg = '&nbsp;';}
   if (!$row) { $row=1; }
   if (!$column) { $column=1; }

   if ($msg =~ /no data/i) { $msg =''; }
   if ($msg eq "") { $msg =''; }
   if ($color =~ /red|\#FF8080/i) {
   		print "<TD colspan=\"$column\" rowspan=\"$row\" class=\"alert alert-danger\">". $msg .'</TD>';
   } elsif ($color =~ /green|33FF66|CCFF99/i) {
   	  print "<TD colspan=\"$column\" rowspan=\"$row\" class=\"alert alert-success\">". $msg .'</TD>';
   } elsif ($color =~ /amber|yellow|orange|FFFF66|CC6633/i) {
   	  print "<TD colspan=\"$column\" rowspan=\"$row\" class=\"alert alert-warning\">". $msg .'</TD>';
   } else {
   	  print "<TD colspan=\"$column\" rowspan=\"$row\">" . $msg . '</TD>';
   }
}

sub tableDataSingleRow
{
   my ($l,$color) = @_;
   if (!$color) { $color = 'FFFFFF'; }
   if ($l =~ /unknown/i) {$color=$grey;}
   #if ($l =~ /^$/) {   $l = '&nbsp;';}
   print "<TD" . $l .'</TD>'."\n";

   if ($l =~ /no data/i) { $l =''; }
   if ($l eq "") { $l =''; }
   if ($color =~ /red|\#FF8080/i) {
   		print "<TD class=\"alert alert-danger\">". $l .'</TD>';
   } elsif ($color =~ /green|33FF66|CCFF99/i) {
   	  print "<TD class=\"alert alert-success\">". $l .'</TD>';
   } elsif ($color =~ /amber|yellow|orange|FFFF66|CC6633/i) {
   	  print "<TD class=\"alert alert-warning\">". $l .'</TD>';
   } else {
   	  print "<TD>" . $l . '</TD>';
   }
}

sub tableDataWidth
{
   my ($l,$w,$color,$col) = @_;
   if (!$color) { $color = 'FFFFFF'; }
   if (!$w) { $w = 1; }
   if (!$col) { $col = 1; }
   #if ($l =~ /^$/) {   $l = '&nbsp;';}
   print "<TH colspan=\"$col\">" . $l .'</TH>'."\n";
}

sub display_html
{
   my ($fields) = @_;

   my ($row, $col);

   ######################### Main #########
   print '<TABLE>'."\n";
   my $debug = 0;

   my $max_rows = scalar(keys %{$fields}) + 1;
   my $max_cols = 0;

   # Determine max number of columns in the table
   for ($row=1; $row <= $max_rows; $row++) {

      if (defined($fields->{$row})) {

         my $num_cols = 0;

         foreach my $col (keys %{$fields->{$row}}) {
            $num_cols++ if (defined($fields->{$row}{$col}));
            $num_cols++ if (defined($fields->{$row}{$col}{VALUE_1}));
            $num_cols++ if (defined($fields->{$row}{$col}{VALUE_2}));
            $num_cols++ if (defined($fields->{$row}{$col}{VALUE_3}));
            $num_cols+=$fields->{$row}{$col}{COLUMN_SPAN} if (defined($fields->{$row}{$col}{COLUMN_SPAN}));

            $max_cols = $num_cols if ($num_cols > $max_cols);
         }
      }
   }

   #Iterate each row and generate html for each field
   for ($row=1; $row <= $max_rows; $row++) {

      print '<TR>'."\n";

      for ($col=1; $col <= $max_cols; $col++) {


         next if (not defined($fields->{$row}{$col}{FIELD_NAME}));

         #print "[$row][$col] = $fields->{$row}{$col}{FIELD_NAME}\n";
         my $col_span = $fields->{$row}{$col}{COLUMN_SPAN} || "1";
         my $row_span = $fields->{$row}{$col}{ROW_SPAN} || "1";
         my $font_size = $fields->{$row}{$col}{FONT_SIZE} || "3";
         my $color_1 = $fields->{$row}{$col}{COLOR_1} || "";
         my $color_2 = $fields->{$row}{$col}{COLOR_2} || "";
         my $color_3 = $fields->{$row}{$col}{COLOR_3} || "";

         my $field_name = $fields->{$row}{$col}{FIELD_NAME} || "";
         my $field_value1 = $fields->{$row}{$col}{VALUE_1} || "";
         my $field_value2 = $fields->{$row}{$col}{VALUE_2} || "";
         my $field_value3 = $fields->{$row}{$col}{VALUE_3} || "";


         my $width = $fields->{$row}{$col}{WIDTH};


         if ($fields->{$row}{$col}{IS_HEADER}) {
            #($msg,$color,$column,$size,$row)
            if ($debug) { print "tableHeaderColumn($field_name,$color_1,$col_span,$font_size,$row_span)\n";}
            if (not $debug) {tableHeaderColumn($field_name,$color_1,$col_span,$font_size,$row_span);}

         } else {
            # Data Row


            if (defined($fields->{$row}{$col}{WIDTH})) {
               #($l,$w,$color,$col)
               if ($debug) {print "tableDataWidth($field_name,$fields->{$row}{$col}{WIDTH},$color_1,$col_span)\n";}
               if (not $debug) {tableDataWidth($field_name,$fields->{$row}{$col}{WIDTH},$color_1,$col_span);}

            } else {

               #($msg,$row,$color,$size)
               #Label
               if ($debug) {print "tableDataMultipleRow($field_name,$row_span,$color_1, $font_size)\n";   }
               if (not $debug) {tableDataMultipleRow($field_name,$row_span,"", "3.0");}

               #1st Value
               if (defined($fields->{$row}{$col}{VALUE_1})) {
                  if ($debug) {print "tableDataMultipleRow($field_value1,$row_span,$color_1, $font_size)\n";   }
                  if (not $debug) {tableDataMultipleRow($field_value1,$row_span,$color_1, $font_size);}
               }

               #2nd Value
               if (defined($fields->{$row}{$col}{VALUE_2})) {
                  if ($debug) {print "tableDataMultipleRow($field_value2,$row_span,$color_2, $font_size)\n";}
                  if (not $debug) {tableDataMultipleRow($field_value2,$row_span,$color_2, $font_size);}
               }
               #3rd Value
               if (defined($fields->{$row}{$col}{VALUE_3})) {
                  if ($debug) {print "tableDataMultipleRow($field_value3,$row_span,$color_3, $font_size)\n";}
                  if (not $debug) {tableDataMultipleRow($field_value3,$row_span,$color_3, $font_size);}
               }
            }
         }

         if (defined($fields->{$row}{$col}{POST_HTML})) {
             print "$fields->{$row}{$col}{POST_HTML}\n";
         }
      }

      print '</TR>'."\n";

   }

}

sub uri_encode
{
	my ($uri_component) = @_;

	$uri_component =~ s/\%/%25/g;

	$uri_component =~ s/ /%20/g;
	$uri_component =~ s/!/%21/g;
	$uri_component =~ s/#/%23/g;
	$uri_component =~ s/\$/%24/g;
	$uri_component =~ s/&/%26/g;
	$uri_component =~ s/\'/%27/g;
	$uri_component =~ s/\(/%28/g;
	$uri_component =~ s/\)/%29/g;
	$uri_component =~ s/\*/%2A/g;
	$uri_component =~ s/\+/%2B/g;
	$uri_component =~ s/,/%2C/g;
	$uri_component =~ s/\//%2F/g;
	$uri_component =~ s/:/%3A/g;
	$uri_component =~ s/;/%3B/g;
	$uri_component =~ s/=/%3D/g;
	$uri_component =~ s/\?/%3F/g;
	$uri_component =~ s/@/%40/g;
	$uri_component =~ s/\[/%5B/g;
	$uri_component =~ s/\]/%5D/g;

	return $uri_component;
}

sub rep_start
{
	my ($embed_in_oc, $page_title) = @_;

	print "Content-type: text/html\n\n";
	print "<html><head>\n";

	if(!$embed_in_oc)
	{
print <<END1;
<!DOCTYPE html>
<html>
<head>
	<meta charset="UTF-8">
        <title>$page_title</title>
	<meta http-equiv="X-UA-Compatible" content="IE=edge" />
        <link rel="stylesheet" type="text/css" href="../../../ui5/resources/css/font-metric.css" />
        <link rel="stylesheet" href="../../../ui5/resources/hpetheme/css/bootstrap.css">
        <link rel="stylesheet" href="../../../ui5/resources/depends/c3/c3.css">
        <link href="../../../ui5/resources/css/styles.css" rel="stylesheet">

		<link rel="stylesheet" href="../../../ui5/resources/css/filter.formatter.css">

      <script>
         jQuery(function() {
            jQuery( ".tooltip-cell" ).tooltip({
               position: { my: "left-175 bottom-25", collision: 'none' },
               show: false,
               hide: false
            });
         });
      </script>

      <script>
         jQuery(document).ready(function(){
            jQuery("#toolspen").tablesorter({
               sortList: [[1,0],[2,0],[3,0],[4,0]],

               textExtraction: function (node) {
                                 var txt = \$(node).text();
                                 txt = txt.replace('No Data', '');
                                 return txt;
               },
               emptyTo: 'bottom',
                 widgets: ["filter"],
                 headers: {
                    '.count-name':{ filter: false },
                    '.dmap':{filter: false }
                 },
                 widgetOptions : {
                    filter_cssFilter   : '',
                  filter_placeholder : { search : 'search'},
                    filter_functions : {
                 }
            }

            }).bind('filterEnd',function(e, filter){
               console.log('Filter end');
               var rowCount = 0;
               \$('.tablesorter tr').each(function(){
                    if(!\$(this).hasClass('filtered')){
                       var \$td = \$(this).find('td:nth-child(1)');
                       if(\$td != null && \$td.length > 0){
                            if(rowCount == 0){
                             rowCount++;
                          } else {
                             \$(this).find('td:nth-child(1)').html(rowCount);
                             rowCount++;
                          }
                       }
                    }
                 });

            });
         });

         function setDefaults()
         {
            var region = getParameterByName('region');
            var capability = getParameterByName('capability');
            var customer = getParameterByName('customer');
            var status_filter = getParameterByName('status_filter');

            if(region != null)
               document.getElementById('region').value = region;
            if(capability != null)
               document.getElementById('capability').value = capability;
            if(customer != null)
               document.getElementById('customer').value = customer;
            if(status_filter != null)
               document.getElementById('status_filter').value = status_filter;
         }

         function getLocalDate(incomingUTCDt) {
            var localDate = new Date(incomingUTCDt);
            return localDate;
         }

         function getParameterByName(name)
         {
             name = name.replace(/[\[]/, "\\[").replace(/[\]]/, "\\]");
             var regex = new RegExp("[\\?&]" + name + "=([^&#]*)"),
                 results = regex.exec(location.search);
             var ret =  results === null ? "" : decodeURIComponent(results[1].replace(/\\+/g, " "));
             return ret === "" ? null : ret;
         }

      </script>

	  <style>
         .tooltip-cell:hover {
            color: #2AD2C9 !important;
            cursor: pointer;
            cursor: hand;
         }

         .ui-tooltip {
            position: absolute;
			 width: 550px !important;

         }

         .ui-helper-hidden-accessible {
            visibility: hidden;
            position: absolute;
         }

         .ui-tooltip-content {
            border: 1px solid #2AD2C9 !important;
            font-size:12pt;
         }

         .tablesorter {
             width: auto;
         }
         .tablesorter .tablesorter-filter {
             width: 70px;
         }
         .tablesorter .filtered {
             display: none;
         }


         /* ajax error row */
         .tablesorter .tablesorter-errorRow td {
          text-align: center;
          cursor: pointer;
          background-color: #e6bf99;
         }
      </style>


</head>
<body>
END1
	}
}

sub rep_finish
{
	my ($embed_in_oc) = @_;

	if(!$embed_in_oc)
	{

print <<END;
	<script src="../../../ui5/resources/depends/jquery/jquery-1.11.3.min.js"></script>
	<script src="../../../ui5/resources/depends/jquery/jquery.cookie.js"></script>
	<script src="../../../ui5/resources/depends/jquery/jquery.ba-hashchange.min.js"></script>
	<script src="../../../ui5/resources/depends/bootstrap-3.3.5-dist/js/bootstrap.min.js"></script>
	<script src="../../../ui5/resources/js/menu.js"></script>
	<script src="../../../ui5/resources/depends/c3/d3.min.js" charset="utf-8"></script>
	<script src="../../../ui5/resources/depends/c3/c3.min.js"></script>
	<script src="../../../ui5/resources/js/charts.js"></script>
	<script src="../../../ui5/resources/js/l2-summary-charts.js"></script>

	<script src="../../../ui5/resources/depends/tablesorter/jquery.tablesorter.js"></script>
    <script src="../../../ui5/resources/depends/tablesorter/widgets/widget-filter.js"></script>

</body>
</html>
END

	}
}


sub make_id
{
	my ($str) = @_;
	$str =~ s/<[^<]*>//g;
	$str =~ s/[^a-zA-Z0-9_-]*//g;
	return('rpt-' . lc($str));
}


sub create_graph_elements {

	my ($elements) = @_;

	print '<div id="oc-l2-report">
			<div id="oc-l2-title" class="l2-title">Graphs
  		<div class="l2-min-max glyphicon glyphicon-plus"></div>
  		<div id="oc-l2-graph" class="hide">';

  		foreach my $data (@$elements) {
  			print '<div id="' . $data->{'div-id'} . '"';
  			foreach my $key (keys %$data) {
  				next if ($key =~ /div-id|class/i);
  				print " data-$key\=\"$data->{$key}\"";
  			}
  			print 'class="oc-tbl-graph-item inline-block-graph"><div class="position-abs"></div></div>';
  		}

 print '</div> </div> </div>';

}

sub create_footer {
	my ($footer) = @_;
	my $data_element;
	if ($footer->{'label_span'} > 0) {
		$data_element = "data-label-span\=\'$footer->{label_span}\'"
	}	else {
		$data_element = "data-label-span\=1"
	}

	if ($footer->{columns} ne "") {
		$data_element .= " data-footer-columns\=\'$footer->{columns}\'";

		print '<TFOOT id="table-footer-font"' . $data_element . '></TFOOT>';

	}

}

sub api_graph_translate{
	my ($graph_data, $gnum)	= @_;
	use vars qw(@common_graph_colors);
	my $color_count=0;
	my %api_chartdata;
	
	#print "API Graph Translator<br>";
	#print Dumper $graph_data;
	foreach my $x (@{$graph_data->{columns}}){
		my %chartdata;
		#print "Dataset:@$x[0]<br>";				
		for (my $i = 0; $i < @$x; $i++) {		
			#print "Columns Element:@$x[$i]<br>";					
			if(@$x[0] eq "x" and $i>0){
				push@{$api_chartdata{labels}},@$x[$i];
			}elsif(@$x[0] ne "x" and $i>0){
				push @{$chartdata{data}},@$x[$i];
			}			
		}
		
		$chartdata{label}="@$x[0]" if(@$x[0] ne "x");
		$chartdata{backgroundColor}=$common_graph_colors[$color_count] if(@$x[0] ne "x");
		$chartdata{borderColor}=$common_graph_colors[$color_count] if(@$x[0] ne "x");
		$color_count++;
	#	print "Chartdata @$x[0]<br>";
	#	print Dumper \%chartdata;
	#	print "Chartdata END<br>";
		push @{$api_chartdata{datasets}}, \%chartdata if(@$x[0] ne "x");
	#	print "API CHARTDATA<br>";
	#	print Dumper \%api_chartdata;
	#	print "API CHARTDATA END<br>";
		#undef %chartdata;
	}
	
	#my $graph_json = jsonMessage(\%api_chartdata);	
	return (\%api_chartdata);
}

sub api_json{
	my ($xls_attr, $teams) = @_;	
	
	my %tmp;
	delete $xls_attr->{API};		
	
	## This is an L1 Report with Two tables and multiple Charts
	if(defined($xls_attr->{MULTI_TABLE})){
		foreach my $tbl(keys %{$xls_attr}){
			next if ($tbl =~ /MULTI_TABLE|MULTI_CHART|AIP_FORM/);	
			next if ($tbl =~/XLS_Y|XLS_X/);
			if($tbl=~/l1-graph|l1-history-chart/){
				$tmp{$tbl}=$xls_attr->{$tbl};
			}else{
				$tmp{$tbl}{TABLEHEADER} = $xls_attr->{$tbl}{TABLEHEADER};
				$tmp{$tbl}{TABLEDATA} = $xls_attr->{$tbl}{TABLEDATA};
				$tmp{$tbl}{XLS_X_MAX} = $xls_attr->{$tbl}{XLS_X_MAX};
			}
		}							
	## Else just send the standard Table data
	}else{
		$tmp{TABLEHEADER} = $xls_attr->{TABLEHEADER};
		$tmp{TABLEDATA} = $xls_attr->{TABLEDATA};
		$tmp{XLS_X_MAX} = $xls_attr->{XLS_X_MAX};
					
		$xls_attr->{TEAMS}=$teams;
	}
	
	## This has Multiple Charts
	if(defined($xls_attr->{MULTI_CHART})){
		foreach my $cht(keys %{$xls_attr->{MULTI_CHART}}){			
			#print "MULTI_CHART: $cht<br>"						;
			#print Dumper $xls_attr->{MULTI_CHART}{$cht};
			#print "MULTI_CHART END<br>"	;
			$tmp{$cht}=$xls_attr->{MULTI_CHART}{$cht};			
		}						
	}
	## This has a Menu/Form
	if(defined($xls_attr->{AIP_FORM})){
		foreach my $item(keys %{$xls_attr->{AIP_FORM}}){			
			#print "FORM: $item<br>"						;
			#print Dumper $xls_attr->{AIP_FORM}{$item};
			#print "AIP_FORM END<br>"	;
			$tmp{"data-menus"}{$item}=$xls_attr->{AIP_FORM}{$item};			
		}								
	}
			
	my $json_total = JSON->new->allow_nonref;
	my $json_ref = $json_total->pretty->encode(\%tmp);
	print "API JSON\n";
	print $json_ref . "\n";
	#print Dumper \%tmp;
	#print Dumper \%tmp;
	#print "$_ $tmp{$_}\n" for (keys %tmp);
	#print \%tmp;
		
}

1;
