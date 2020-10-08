#!/opt/perl/bin/perl

use strict;
use Sys::Hostname;
use File::Basename;
use File::Copy;
use File::Temp "tempfile";
use FileHandle;
use Data::Dumper;
use File::Path qw(make_path);
use Time::Local;
use POSIX qw(strftime);
#use lib '/opt/OV/www/cgi-bin/GTOD_CC/modules';
use lib '/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/modules';
use lib '/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/modules/pm';
use lib '/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/modules/database';

use dbutilities;
use JSON;
use Storable;

use utf8;
use Encode qw(encode_utf8);
use lib '/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/modules/pm';
use CommonColor;
use Net::Domain qw (hostname hostfqdn hostdomain);
use YAML::XS 'LoadFile';
use MIME::Base64;
use Deep::Hash::Utils qw(reach slurp nest deepvalue);
## Set this to 0 to activate user account mapping filter
our $use_account_filter= 1;
my %user_cache;

#our $CONFIGFILE = "/opt/OV/www/cgi-bin/KMM/dashboard.cfg";
our $base_dir = "/opt/cloudhost/apache/www/cgi-bin/GTOD_CC";
our $cache_dir = "$base_dir/cache";
our $rawdata_dir = "$base_dir/rawcache";
our $cfg_dir = "$base_dir/cfg";
our $drilldown_dir = "/cgi-bin/GTOD_CC/l3_drilldowns";
our $l2_report_dir = "/cgi-bin/GTOD_CC/l2_reports";
our $report_cache = "$base_dir/cache/l3_cache";
our $l1_report_dir = "/cgi-bin/GTOD_CC/l1_reports";
our $health_cfg_dir = "/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/cfg/healthchecks";
##Migrated from T1
our %platform = ('wintel' => 'win', 'midrange' => 'hp-ux|sol|aix|sun|tru|centos|linux', 'esx' => 'esx', 'storage' => 'storage|san|tape', 'other' => 'appliance|ups|cabinet');
our $om_not_supported = 'other|unknown|windows 2000|windows nt|windows 7|windows xp|hp-ux 11.0|hp-ux 10|solaris 8|solaris 7|esx|redhat 3|redhat 4|redhat es 4|redhat es 3|redhat as 3|aix 4|fabricos|ibm i|citrix';
our $hpsa_not_supported = 'other|unknown|windows 2000|windows nt|windows 7|windows xp|hp-ux 11.0|hp-ux 10|solaris 9|solaris 8|solaris 7|redhat 3|redhat 4|redhat es 4|redhat es 3|redhat as 3|aix 4|aix 5.1|aix 5.2|aix 5.3|fabricos|ibm i|citrix';
our $ddmi_not_supported = 'other|unknown|windows nt|windows 7|windows xp|hp-ux 11.0|hp-ux 10|aix 4|fabricos|ibm i|citrix';
our $dbmon_not_supported = 'db2|oracle(.*?)10g|oracle(.*?)::10\.|oracle(.*?)::9\.|oracle(.*?)::8\.|ms-sql(.*?)2000|ms-sql(.*?)8\.|mysql(.*?)5';
our %db_platform = ('oracle' => 'oracle', 'mssql' => 'ms-sql', 'sybase' => 'sybase','mysql' => 'mysql','progress' => 'progress');
our $backupmon_supported = 'dataprotector|netbackup|backup exec|networker|tsm';
our $admon_supported = '2003|2008|2012';
our $exmon_supported = '2003|2008|2012';
use vars qw($green $red $amber $grey $orange $cyan $cgreen $lgrey $info $info2 $dgrey $voilet $lgolden $lblue $hpe);
my %eol_wintel_cfg = ('windows\s*nt'=> 0, '2000' => 0, '2003' => 0);
my %eol_midrange_cfg = ('solaris\s*8' => 0, 'solaris\s*9' => 0, 'aix 5' => 0, 'redhat(.*?) 4\.' => 0, 'hp-ux(.*?) 11\.23' => 12,  'hp-ux(.*?) 11\.11' => 12);
my %eol_db_cfg = ('oracle(.*?)10g' => 0,'oracle(.*?)::10\.' => 0,'oracle(.*?)::9\.' => 0,'oracle(.*?)::8\.' => 0, 'ms-sql(.*?)2000' => 0,'ms-sql(.*?)8\.' => 0, 'mysql(.*?)5' => 0, 'oracle(.*?)::11\.1' => 12, 'ms-sql(.*?)2005' => 12,'ms-sql(.*?)9\.' => 12,);
my %eol_dataprotector = ('^A\.0[1-7]\.(.*?)' => 0,'^A\.08\.(.*?)' => 12,'^0[1-7]\.(.*?)' => 0,'^08\.(.*?)' => 12);
our $hostname =`/bin/hostname`;
chomp($hostname);
##PDXC
my $aws = '/usr/local/bin/aws';
my $md5_cmd = '/usr/bin/md5sum';
####Functions##

my %_cfg;
_read_config();
_log_access();

sub _log_access
{
	if (defined $ENV{OC_AUTH_UID}) {

		my $host=hostname();
		my $log_file = '/opt/cloudhost/logs/apache/common_functions_log.' . $host . '-' . POSIX::strftime("%b%Y", localtime time);

		my $log_time = time();
		my $date_str = scalar localtime($log_time);

		my $ui_type ="standard";
		$ui_type = "ocmobile" if ($ENV{HTTP_REFERER} =~ /ocmobile|ui6/i);
		$ui_type = "aip" if ($ENV{HTTP_REFERER} =~ /insight|aip/i);

		if ($ui_type !~ /aip/i) {
			open LOG , ">>$log_file" or die "Can't open debug file $log_file for writing! $!";
			print LOG "Time:($log_time):$date_str~~~User:$ENV{OC_AUTH_UID}~~~SCRIPT:$0~~~QUERY_STRING:$ENV{QUERY_STRING}~~~INTERFACE:$ui_type\n";
			close LOG;
		}
	}

}


sub log_daily_l1
{
	my ($tile_id, $l1_cache, $run_date, $dry_run, $properties) = @_;

	my $tile_start_time = time();
	
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
	$year += 1900;
	$mon++;
	my $my_run_date = sprintf '%d-%02d-%02d', $year, $mon, $mday;
	
	$run_date = $my_run_date if ($run_date eq "");  # Set it if blank is passed in
	$properties = "l1_cache_db.cfg" if ($properties eq ""); # Set it if blank is passed in
	$dry_run = 0 if ($dry_run eq ""); # Set it if blank is passed in

	#my $process_area = $tiles_by_id->{$tile_id}{process_area};
	#my $function_area = $tiles_by_id->{$tile_id}{function_area};


	my @db;

	#$l1_availability{$owner}{$region_key}{$center_key}{$capability}{server_up}
	foreach my $owner (keys %{$l1_cache}) {
		next if (ref($l1_cache->{$owner}) !~ /hash/i);
		foreach my $region_key (keys %{$l1_cache->{$owner}}) {
			next if (ref($l1_cache->{$owner}{$region_key}) !~ /hash/i);
			foreach my $center_key (keys %{$l1_cache->{$owner}{$region_key}}) {
				next if (ref($l1_cache->{$owner}{$region_key}{$center_key}) !~ /hash/i);
				foreach my $capability (keys %{$l1_cache->{$owner}{$region_key}{$center_key}}) {
					next if (ref($l1_cache->{$owner}{$region_key}{$center_key}{$capability}) !~ /hash/i);
					my %db_row_item;

					$db_row_item{a000_exec_date_id} = $run_date;
					$db_row_item{a001_owner} = $owner;
					$db_row_item{a002_region_key} = $region_key;
					$db_row_item{a003_center_key} = $center_key;
					$db_row_item{a004_capability} = $capability;
					#$db_row_item{a005_process_area} = $process_area;
					#$db_row_item{a006_function_area} = $function_area;

					#print "owner = $owner:region_key=$region_key:center_key=$center_key:capability = $capability $l1_cache->{$owner}{$region_key}{$center_key}{$capability}\n";
					foreach my $metric (keys %{$l1_cache->{$owner}{$region_key}{$center_key}{$capability}}) {

						# People shouldnt be putting hashs or arrays here... but they do...  :(
						next if (ref($l1_cache->{$owner}{$region_key}{$center_key}{$capability}{$metric}) =~ /hash|array/i);

						# These are dodgy metrics and Martins loader doesnt like them...
						next if ($metric eq "");
						next if ($metric eq "ALL" and $tile_id !~ /instance/i);
						next if ($metric eq "null");

						#print "METRIC \"$metric\" = $l1_cache->{$owner}{$region_key}{$center_key}{$capability}{$metric}\n";

						#MAke the column names safe...
						my $metric_label = $metric;
						$metric_label =~ s/\s+/\_/g;
						$metric_label =~ s/\://g;
						$metric_label =~ s/\///g;
						$metric_label =~ s/^all$/total/ig;


						$db_row_item{"c000_${metric_label}"} = $l1_cache->{$owner}{$region_key}{$center_key}{$capability}{$metric};
					}


					push(@db, \%db_row_item);
				}
			}
		}
	}
	undef($l1_cache);
	
	$ENV{CLASSPATH} = "$base_dir/cfg:$base_dir/modules/database/dashboardj.jar";

	my $table_name = "l1_".$tile_id;
	my @id_fields = qw(exec_date_id owner region_key center_key capability process_area function_area);
	&dbutilities::log_dashboard_db(\@db, $table_name, '[a-z]\d\d\d_', undef, \@id_fields);

	# CSV is now setup in the tmp dir - now log the data into DB
	my $log_db_cmd = "java -DPROPERTIES_FILE=$properties dashboardj.ListLoader  $table_name";

	system("$log_db_cmd") if(!$dry_run);


	my $tile_log_time = time() - $tile_start_time;
	print "Finished Logging L1 tile data for tile_id = $tile_id.  Took $tile_log_time seconds\n";

}

sub get_aipdb_metric_details
{
	my ($widget_name) = @_;
	my $sql;
	my %metrics;
	my $cfg = read_config();
	eval {	
  	my $dbh = DBI->connect('dbi:ODBC:aip_db', $cfg->{OCDB_USER}, $cfg->{OCDB_PASSWORD})	or die "Cannot connect to oc_config database $DBI::errstr\n";  	  	  	
  	$sql = "select report_id, meta_name as metric_name, short_name, description, danger_threshold, warning_threshold, normal_threshold, measturement, priority, ranking, b.title, meta_name, default_order 
  					from report_metrics with (nolock) join report as b with (nolock) on report_id=b.id where b.report_name like \'$widget_name\' and DATALENGTH(meta_name) > 0 ";
  	#print "SQL = $sql\n";  	
  	my $sth;
  	$sth = $dbh->prepare($sql);
  	$sth->execute();
  	# Store database results in hash  	
		
  	while (my @row = $sth->fetchrow_array) {     
  		#print Dumper \@row;
  		$metrics{$row[2]}{report_id}=$row[0];
  		$metrics{$row[2]}{metric_name}=$row[1];
  		$metrics{$row[2]}{meta_name}=$row[11];
  		$metrics{$row[2]}{short_name}=$row[2];
  		$metrics{$row[2]}{description}=$row[3];
  		$metrics{$row[2]}{danger_threshold}=$row[4];
  		$metrics{$row[2]}{warning_threshold}=$row[5];
  		$metrics{$row[2]}{normal_threshold}=$row[6];
  		$metrics{$row[2]}{measurement}=$row[7];
  		$metrics{$row[2]}{priority}=$row[8];
  		$metrics{$row[2]}{ranking}=$row[9];
  		$metrics{$row[2]}{title}=$row[10];
  		$metrics{$row[2]}{default_order}=$row[12];
  	}
  	# Finish database session
  	$sth->finish;
  	$dbh->disconnect;
	};
	return(\%metrics)	;
}

sub log_daily_l1_perc
{
   my ($tile_id, $l1_cache, $run_date, $dry_run, $properties) = @_;

   my %rankings;
   my @db;
   my @baseline_db;
   my %l1_metric_percentile;

   my $tile_start_time = time();
   
   my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
	 $year += 1900; $mon++;
	 my $my_run_date = sprintf '%d-%02d-%02d', $year, $mon, $mday;
	
	 
   $run_date = $my_run_date if ($run_date eq "");  # Set it if blank is passed in
	 $properties = "l1_cache_db.cfg" if ($properties eq ""); # Set it if blank is passed in
	 $dry_run = 0 if ($dry_run eq ""); # Set it if blank is passed in

		# Read Main Configuration File
	 my $cfg = read_config();
	 
	 my @list = ('account_reg');
	 my %cache = load_cache(\@list);
	 my %account_reg = %{$cache{account_reg}};
		
	 my $metric_details = get_aipdb_metric_details($tile_id);
   
   foreach my $owner (keys %{$l1_cache}) {
      next if (ref($l1_cache->{$owner}) !~ /hash/i);
      next if $owner !~ /owner|na/i;
         
      foreach my $region_key (keys %{$l1_cache->{$owner}}) {
         next if (ref($l1_cache->{$owner}{$region_key}) !~ /hash/i);
         next if $region_key =~ /\:/;
            
         foreach my $center_key (keys %{$l1_cache->{$owner}{$region_key}}) {
            next if (ref($l1_cache->{$owner}{$region_key}{$center_key}) !~ /hash/i);
            next if $center_key ne 'center:ALL';
               
            foreach my $capability (keys %{$l1_cache->{$owner}{$region_key}{$center_key}}) {
               next if (ref($l1_cache->{$owner}{$region_key}{$center_key}{$capability}) !~ /hash/i);
               next if $capability ne 'ALL';
                  
               foreach my $metric (keys %{$l1_cache->{$owner}{$region_key}{$center_key}{$capability}}) {
                  next if (ref($l1_cache->{$owner}{$region_key}{$center_key}{$capability}{$metric}) =~ /hash|array/i);
                  next if ($metric eq "");
                  next if ($metric eq "ALL" and $tile_id !~ /instance/i);
                  next if ($metric eq "null"); 
                  next if ($metric =~ /num_account/i);
                  
                  # Retrieve which l1_filters the account belongs to
                  my $account = $region_key; 
                  my @step_one_filters = 'all';                        
                  push @step_one_filters, "region:$account_reg{$account}{oc_region}";                        
                  foreach my $adhoc_group (@{$account_reg{$account}{adhoc_grouping}}) {push @step_one_filters, "adhoc:$adhoc_group";}
                  #foreach my $cluster_group (@{$account_reg{$account}{idm_cluster}}) {push @step_one_filters, "idm_cluster:$cluster_group";}
                  #foreach my $cluster_hub_group (@{$account_reg{$account}{idm_cluster_hub}}) {push @step_one_filters, "idm_cluster_hub:$cluster_hub_group";}
                  #foreach my $mh_subregion (@{$account_reg{$account}{mh_region_subregion}}) {push @step_one_filters, "mh_region_subregion:$mh_subregion";}
                  #foreach my $ito_leader (@{$account_reg{$account}{oc_run_unit}}) {push @step_one_filters, "oc_run_unit:$ito_leader";}
                   
                  # Push rounded metric values in to their account group arrays
                  if ($l1_cache->{$owner}{$region_key}{$center_key}{$capability}{$metric} > 0){
                     my $rounded = sprintf "%d",$l1_cache->{$owner}{$region_key}{$center_key}{$capability}{$metric};
                           
                     foreach my $sof (@step_one_filters) {
                       push @{$rankings{$tile_id}{$sof}{$metric}{VALUES}}, $rounded;
                     }                              
                  }
                  #print "CACHE METRIC = $metric : $metric_details->{$metric}{ranking}\n";
               }                     
            }
         }
      }         
   }   

   undef($l1_cache);      
    
   # Calculate the Global Percentiles for each metric      
   foreach my $sof (keys %{$rankings{$tile_id}}) {
      
      my %db_row_item;                  
      $db_row_item{a000_exec_date_id} = $run_date;
      $db_row_item{a001_account_group_id} = $sof;

      foreach my $metric (keys %{$rankings{$tile_id}{$sof}}) {
 #print "Metric = $metric\n";                 
         my @ordered;
         if (scalar(@{$rankings{$tile_id}{$sof}{$metric}{VALUES}}) > 0) {
         	
            #@ordered = sort {$b <=> $a} @{$rankings{$tile_id}{$sof}{$metric}{VALUES}} if ($tiles_by_id->{$tile_id}{metrics}{$metric}{ranking} =~ /standard|none/i);
            #@ordered = sort {$a <=> $b} @{$rankings{$tile_id}{$sof}{$metric}{VALUES}} if ($tiles_by_id->{$tile_id}{metrics}{$metric}{ranking} =~ /inverted/i);  
            
      
            @ordered = sort {$b <=> $a} @{$rankings{$tile_id}{$sof}{$metric}{VALUES}} if ($metric_details->{$metric}{ranking} =~ /standard|none/i);
            @ordered = sort {$a <=> $b} @{$rankings{$tile_id}{$sof}{$metric}{VALUES}} if ($metric_details->{$metric}{ranking} =~ /inverted/i);   
            
            
         } else {
            next;
         }

 
         my $len10 = sprintf "%d", scalar(@ordered) * 0.10;
         my $len25 = sprintf "%d", scalar(@ordered) * 0.25;
         my $len50 = sprintf "%d", scalar(@ordered) * 0.5;
         my $len75 = sprintf "%d", scalar(@ordered) * 0.75;

         $l1_metric_percentile{"bl10pct_" . $metric}{$sof}{VALUE} = $ordered[$len10];
         $l1_metric_percentile{"bl25pct_" . $metric}{$sof}{VALUE} = $ordered[$len25];
         $l1_metric_percentile{"bl50pct_" . $metric}{$sof}{VALUE} = $ordered[$len50];
         $l1_metric_percentile{"bl75pct_" . $metric}{$sof}{VALUE} = $ordered[$len75];

         $db_row_item{"c000_${metric}_10pct"} = $ordered[$len10];
         $db_row_item{"c000_${metric}_25pct"} = $ordered[$len25];
         $db_row_item{"c000_${metric}_50pct"} = $ordered[$len50];
         $db_row_item{"c000_${metric}_75pct"} = $ordered[$len75];         
      }
      
      push(@db, \%db_row_item);
   }
   
 
   $ENV{CLASSPATH} = "$base_dir/cfg:$base_dir/modules/database/dashboardj.jar";

   my $table_name = "l1_".$tile_id."_perc";
   my @id_fields = qw(exec_date_id account_group_id);
   &dbutilities::log_dashboard_db(\@db, $table_name, '[a-z]\d\d\d_', undef, \@id_fields);
  
   # CSV is now setup in the tmp dir - now log the data into DB
   my $log_db_cmd = "java -DPROPERTIES_FILE=$properties dashboardj.ListLoader  $table_name";
   print "Running:$log_db_cmd \n";
   system("$log_db_cmd") if(!$dry_run);
   
   save_hash("cache.l1_metric_percentile-${tile_id}", \%l1_metric_percentile, "$cache_dir/l1_cache");
   
   my $tile_log_time = time() - $tile_start_time;
   print "Finished logging l1 tile data for tile_id \'$tile_id\'. Took $tile_log_time seconds.\n";
}

sub get_blocked_sources
{

	my %blocked_sources;

	open(IN, "/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/rawcache/raw_bionix_users");
	while(<IN>) {
		chomp;

		if (/BIONIX_SOURCE_BLOCKED/) {
			my ($account, $blocked_source) = (split(/~~~/, $_))[1,2];

			$blocked_sources{$account}{$blocked_source} = 1;
		}
	}
	close(IN);

	return \%blocked_sources;
}

sub read_master_tile_list
{
   my ($filter_customer, $filter_region_new, $filter_center, $filter_capability) = @_;

   my %tiles_by_id;

   # Ensure correct use of subroutine
   if ($filter_customer and not $filter_capability) {
      die "When calling read_master_tile_list, either supply no paramaters to retrieve just tile attributes, or supply 4 parameters (customer, region, center, capability) if you need to additionally access specified split_l1_cache file\n";
   }

   # Build split cache filename sting components
   my $rk = '';
   if ($filter_region_new) {
      $rk = $filter_region_new;
      $rk = $filter_customer if ($filter_customer !~ /^all$/i);
      $rk =~ s/[^A-Za-z0-9:]//g;
      $rk = '--' . $rk;
   }

   my $ck = '';
   if ($filter_center) {
      $ck = $filter_center;
      $ck =~ s/[^A-Za-z0-9:]//g;
      $ck = '--' . $ck;
   }

   if ($filter_capability) {
      $filter_capability = '--' . $filter_capability;
   }

   # Load master tile list and iterate through tile IDs
   use YAML::XS 'LoadFile';
   my $tile_cfg = LoadFile("/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/cfg/master_tile_list.yaml");

   foreach my $tile_id (keys %{$tile_cfg}) {

      my $l1_cache_file = "/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/cache/l1_cache/" . $tile_cfg->{$tile_id}{l1_cache};
      my $metadata_file = "/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/cache/l1_cache/metadata/" . $tile_cfg->{$tile_id}{l1_metadata};
      my $split_l1_file = "/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/cache/l1_cache/by_filters/" . $tile_cfg->{$tile_id}{split_l1_cache} . $rk . $ck . $filter_capability;
      my $split_l1_history_file = "/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/cache/l1_cache/by_filters/" . $tile_cfg->{$tile_id}{split_l1_history_cache} . $rk . $ck . $filter_capability;

      my %x = ( 'tile_id' => $tile_id,
                'report_name' => $tile_cfg->{$tile_id}{report_name},
                'report_owner' => $tile_cfg->{$tile_id}{report_owner},
                'report_status' => $tile_cfg->{$tile_id}{report_status},
                'tile_refresh' => $tile_cfg->{$tile_id}{tile_refresh},
                'process_area' => $tile_cfg->{$tile_id}{process_area},
                'function_area' => $tile_cfg->{$tile_id}{function_area},
                'owner_value' => $tile_cfg->{$tile_id}{owner_value},
                'l1_cache_file' => $l1_cache_file,
                'l1_cache_metadata' => $metadata_file,
                'split_l1_cache' => $split_l1_file,
                'split_l1_history_cache' => $split_l1_history_file,
                'min_security_clearance_level' => $tile_cfg->{$tile_id}{min_security_clearance},
                'user_wiki' => $tile_cfg->{$tile_id}{user_wiki},
                'l1_report' => $tile_cfg->{$tile_id}{l1_report},
                'l2_report' => $tile_cfg->{$tile_id}{l2_report});

      $tiles_by_id{$tile_id} = \%x;

      if ($tile_cfg->{$tile_id}{metrics}) {
         $tiles_by_id{$tile_id}{'metrics'} = $tile_cfg->{$tile_id}{metrics};
      }

      if ($tile_cfg->{$tile_id}{metro_tile}) {
         $tiles_by_id{$tile_id}{'metro_tile'} = $tile_cfg->{$tile_id}{metro_tile};
      }

      if ($tile_cfg->{$tile_id}{ma_metric_labels}) {
         $tiles_by_id{$tile_id}{'ma_metric_labels'} = $tile_cfg->{$tile_id}{ma_metric_labels};
      }
   }

   return \%tiles_by_id;
}

#sub read_master_tile_list_old
#{
#   my ($filter_customer, $filter_region_new, $filter_center, $filter_capability) = @_;
#
#   my %tiles_by_id;
#
#   my $CONFIG_FILE = "/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/cfg/master_tile_list.cfg";
#
#
#   #configuration::ci_volume::System CI volume::iAction,iSolve::cache.l1_system_baseline::cache.l1_system_baseline_metadata
#   open(CFG, "$CONFIG_FILE");
#   my @data = <CFG>;
#   close(CFG);
#
#   foreach my $row (@data) {
#      chomp $row;
#      next if ($row =~ /^\s*$/);
#      next if ($row =~ /^\#/);
#      next if ($row !~ /::/);
#
#      my @attr = split(/::/, $row);
#
#
#         my $rk = $filter_region_new;
#
#         $rk = $filter_customer if ($filter_customer !~ /^all$/i);
#         my $ck = $filter_center;
#         $rk =~ s/[^A-Za-z0-9:]//g;
#         $ck =~ s/[^A-Za-z0-9:]//g;
#
#         my $cache_file = "/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/cache/l1_cache/$attr[3]";
#         my $metadata_file = "/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/cache/l1_cache/metadata/$attr[4]";
#         my $split_l1_file = "/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/cache/l1_cache/by_filters/${attr[5]}--$rk--$ck--$filter_capability";
#         my $split_l1_history_file = "/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/cache/l1_cache/by_filters/${attr[6]}--$rk--$ck--$filter_capability";
#         my $min_security_clearance_level = $attr[7];
#
#         my %x = ('tile_id' => $attr[0], 'process_area' => $attr[1], 'function_area' => $attr[2], 'l1_cache_file' => $cache_file, 'l1_cache_metadata' => $metadata_file, 'split_l1_cache' => $split_l1_file, 'split_l1_history_cache' => $split_l1_history_file, 'min_security_clearance_level' => $min_security_clearance_level);
#
#         $tiles_by_id{$attr[0]} = \%x;
#
#   }
#
#   return \%tiles_by_id;
#}

sub read_master_tile_cfg
{
   my ($filter_customer, $filter_region_new, $filter_center, $filter_capability) = @_;

   my %tiles_by_id;

   # Ensure correct use of subroutine
   if ($filter_customer and not $filter_capability) {
      die "When calling read_master_tile_list, either supply no paramaters to retrieve just tile attributes, or supply 4 parameters (customer, region, center, capability) if you need to additionally access specified split_l1_cache file\n";
   }

   # Build split cache filename sting components
   my $rk = '';
   if ($filter_region_new) {
      $rk = $filter_region_new;
      $rk = $filter_customer if ($filter_customer !~ /^all$/i);
      $rk =~ s/[^A-Za-z0-9:]//g;
      $rk = '--' . $rk;
   }

   my $ck = '';
   if ($filter_center) {
      $ck = $filter_center;
      $ck =~ s/[^A-Za-z0-9:]//g;
      $ck = '--' . $ck;
   }

   if ($filter_capability) {
      $filter_capability = '--' . $filter_capability;
   }

   # Load master tile list and iterate through tile IDs
   use YAML::XS 'LoadFile';
   my $tile_cfg = LoadFile("/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/cfg/master_tile_list.yaml");

   foreach my $tile_id (keys %{$tile_cfg}) {

      my $l1_cache_file = "/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/cache/l1_cache/" . $tile_cfg->{$tile_id}{l1_cache};
      my $metadata_file = "/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/cache/l1_cache/metadata/" . $tile_cfg->{$tile_id}{l1_metadata};
      my $split_l1_file = "/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/cache/l1_cache/by_filters/" . $tile_cfg->{$tile_id}{split_l1_cache} . $rk . $ck . $filter_capability;
      my $split_l1_history_file = "/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/cache/l1_cache/by_filters/" . $tile_cfg->{$tile_id}{split_l1_history_cache} . $rk . $ck . $filter_capability;

      my %x = ( 'tile_id' => $tile_id,
                'report_name' => $tile_cfg->{$tile_id}{report_name},
                'report_owner' => $tile_cfg->{$tile_id}{report_owner},
                'report_status' => $tile_cfg->{$tile_id}{report_status},
                'tile_refresh' => $tile_cfg->{$tile_id}{tile_refresh},
                'process_area' => $tile_cfg->{$tile_id}{process_area},
                'function_area' => $tile_cfg->{$tile_id}{function_area},
                'owner_value' => $tile_cfg->{$tile_id}{owner_value},
                'l1_cache_file' => $l1_cache_file,
                'l1_cache_metadata' => $metadata_file,
                'split_l1_cache' => $split_l1_file,
                'split_l1_history_cache' => $split_l1_history_file,
                'min_security_clearance_level' => $tile_cfg->{$tile_id}{min_security_clearance},
                'user_wiki' => $tile_cfg->{$tile_id}{user_wiki},
                'l1_report' => $tile_cfg->{$tile_id}{l1_report},
                'l2_report' => $tile_cfg->{$tile_id}{l2_report});

      $tiles_by_id{$tile_id} = \%x;

      if ($tile_cfg->{$tile_id}{metrics}) {
         $tiles_by_id{$tile_id}{'metrics'} = $tile_cfg->{$tile_id}{metrics};
      }

      if ($tile_cfg->{$tile_id}{metro_tile}) {
         $tiles_by_id{$tile_id}{'metro_tile'} = $tile_cfg->{$tile_id}{metro_tile};
      }

      if ($tile_cfg->{$tile_id}{ma_metric_labels}) {
         $tiles_by_id{$tile_id}{'ma_metric_labels'} = $tile_cfg->{$tile_id}{ma_metric_labels};
      }
   }

   return \%tiles_by_id;
}

#sub read_master_tile_cfg_old
#{
#
#   my %tiles_by_id;
#
#   my $CONFIG_FILE = "/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/cfg/master_tile_list.cfg";
#
#
#   #configuration::ci_volume::System CI volume::iAction,iSolve::cache.l1_system_baseline::cache.l1_system_baseline_metadata
#   open(CFG, "$CONFIG_FILE");
#   my @data = <CFG>;
#   close(CFG);
#
#   foreach my $row (@data) {
#      chomp $row;
#      next if ($row =~ /^\s*$/);
#      next if ($row =~ /^\#/);
#      next if ($row !~ /::/);
#
#      my @attr = split(/::/, $row);
#
#      my $cache_file = "/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/cache/l1_cache/$attr[3]";
#      my $metadata_file = "/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/cache/l1_cache/metadata/$attr[4]";
#      my $split_l1_file = "/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/cache/l1_cache/by_filters/$attr[5]";
#      my $split_l1_history_file = "/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/cache/l1_cache/by_filters/$attr[6]";
#      my $min_security_clearance_level = $attr[7];
#
#      my %x = ('tile_id' => $attr[0], 'process_area' => $attr[1], 'function_area' => $attr[2], 'l1_cache_file' => $cache_file, 'l1_cache_metadata' => $metadata_file, 'split_l1_cache' => $split_l1_file, 'split_l1_history_cache' => $split_l1_history_file, 'min_security_clearance_level' => $min_security_clearance_level);
#
#      $tiles_by_id{$attr[0]} = \%x;
#
#   }
#
#   return \%tiles_by_id;
#}

sub check_region_filter
{
	my ($customer, $filter_region, $account_reg) = @_;

	my $result = 0;

	$result = 1 if ($filter_region =~ /^adhoc\:/ and not account_in_scope($customer, $account_reg, "adhoc_grouping", $filter_region));
	$result = 1 if ($filter_region =~ /^region\:/ and not account_in_scope($customer, $account_reg, "oc_region", $filter_region));
 	$result = 1 if ($filter_region =~ /^region_group\:/ and not account_in_scope($customer, $account_reg, "oc_region_grp", $filter_region));
 	$result = 1 if ($filter_region =~ /^run_unit\:/ and not account_in_scope($customer, $account_reg, "oc_run_unit", $filter_region));
 	$result = 1 if ($filter_region =~ /^onerun_leader\:/ and not account_in_scope($customer, $account_reg, "oc_onerun_leader", $filter_region));
 	$result = 1 if ($filter_region =~ /^location\:/ and not account_in_scope($customer, $account_reg, "oc_delivery_location", $filter_region));
	$result = 1 if ($filter_region =~ /^mh_region_subregion\:/ and not account_in_scope($customer, $account_reg, "mh_region_subregion", $filter_region));
	$result = 1 if ($filter_region =~ /^idm_cluster_hub\:/ and not account_in_scope($customer, $account_reg, "idm_cluster_hub", $filter_region));
	$result = 1 if ($filter_region =~ /^idm_cluster\:/ and not account_in_scope($customer, $account_reg, "idm_cluster", $filter_region));
	$result = 1 if ($filter_region =~ /^idm_hub\:/ and not account_in_scope($customer, $account_reg, "idm_hub", $filter_region));

	return $result;


}


sub check_group_member
{
	my ($access_group) = @_;

	my $user = lc($ENV{OC_AUTH_UID});

	my @list = ('idm_roles_by_email_summary');
	my %cache = load_cache(\@list);
	my %idm_roles = %{$cache{idm_roles_by_email_summary}};

	my $found = 0;
	# iterate through users groups - search for the existance of REMOTE USER having this group
	# Only need to find the first instance of it...

	if (exists($idm_roles{$user}{user_groups})){
		foreach my $user_group (@{$idm_roles{$user}{user_groups}}){
			if (lc($user_group) eq lc($access_group)){
				$found = 1;
				last;
			}
		}
	}

	return $found;
}

sub check_min_security_level
{
	my ($minimum_clearance_level) = @_;


	my @list = ('ngdm_delivery_map');
	my %cache = load_cache(\@list);
	my %ngdm_delivery_map = %{$cache{ngdm_delivery_map}};

	my $found = 0;
	# iterate through every account - search for the existance of REMOTE USER having this role
	# Only need to find the first instance of it...


	foreach my $customer (keys %{$ngdm_delivery_map{'DD_IDMContacts'}}) {

		foreach my $x (@{$ngdm_delivery_map{'DD_IDMContacts'}{$customer}}) {

			$x->{EMPLOYEE_EMAIL} =~ s/hpe/dxc/g;

			if (lc($x->{EMPLOYEE_EMAIL}) eq lc($ENV{OC_AUTH_UID}) and $x->{SECURITY_CLEARANCE_LEVEL} =~ /^level (\d+)/i) {

				my $sec_level = $1;
				if ($sec_level >= $minimum_clearance_level) {
					$found = 1;
					last;
				}

				last if ($found);

			}
			last if ($found);
		}
		last if ($found);
	}


	#moving to IDM Contacts
	#foreach my $customer (keys %{$ngdm_delivery_map{'DD_ACCOUNT_CONTACTS'}}) {
	#	foreach my $r (@{$ngdm_delivery_map{'DD_ACCOUNT_CONTACTS'}{$customer}}) {

	#		if ($role eq "ARL") {
	#			foreach my $e (split(/\,/,$r->{'ITO_ACCOUNT_ONERUN_LEADER_EMAIL'})) {
	#				$found = 1 if ($ENV{REMOTE_USER} eq $e);

	#				$e =~ s/hpe/dxc/g;

	#				$found = 1 if ($ENV{REMOTE_USER} eq $e);

	#				last if ($found);
	#			}
	#		}
	#		last if ($found);
	#	}
	#	last if ($found);
	#}

	return $found;

}

sub build_ci_taxonomy
{
	my ($taxonomy_mapping) = @_;

	my %ci_taxonomy;

	my %guess;

	foreach my $id (keys %{$taxonomy_mapping}) {
		my $node_app = $taxonomy_mapping->{$id}{NODE_APP};
		my $node_group = $taxonomy_mapping->{$id}{NODE_GROUP};
		my $ci_solution_name = $taxonomy_mapping->{$id}{CI_TECH};
		my $tax_cap = $taxonomy_mapping->{$id}{TAX_CAP};
		my $tax_tech = $taxonomy_mapping->{$id}{TAX_TECH};

		my $org = "ITO";
		$org = "EAO" if ($tax_cap =~ /eao/i);

		if (($node_app eq '-' or $node_app eq "") and
 		    ($node_group eq '-' or $node_group eq ""))
		{

			foreach my $attrib (keys %{$taxonomy_mapping->{$id}}){
				$ci_taxonomy{$ci_solution_name}{$org}{$attrib} = $taxonomy_mapping->{$id}{$attrib};
			}

			#$ci_taxonomy{$ci_solution_name}{$org}{TAX_CAP} = $taxonomy_mapping->{$id}{TAX_CAP};
			#$ci_taxonomy{$ci_solution_name}{$org}{TAX_TECH} = $taxonomy_mapping->{$id}{TAX_TECH};
			#$ci_taxonomy{$ci_solution_name}{$org}{BACKUP_FORMULA} = $taxonomy_mapping->{$id}{BACKUP_FORMULA};

		}


		#$guess{$ci_solution_name}{CAPABILITY}{"$tax_cap~~~$tax_tech"}++;
	}

#	foreach my $ci_solution_name (keys %guess) {
#
#		if (defined($ci_taxonomy{$ci_solution_name}{MATCHED_CAP}) and defined($ci_taxonomy{$ci_solution_name}{MATCHED_TECH})) {
#			# Use these - as these are most accurate
#			$ci_taxonomy{$ci_solution_name}{CAPABILITY} = $ci_taxonomy{$ci_solution_name}{MATCHED_CAP};
#			$ci_taxonomy{$ci_solution_name}{TECHNOLOGY} = $ci_taxonomy{$ci_solution_name}{MATCHED_TECH};
#
#			print "$ci_solution_name mapped directly to Capability $ci_taxonomy{$ci_solution_name}{MATCHED_CAP} and Tech $ci_taxonomy{$ci_solution_name}{MATCHED_TECH}\n";
#
#		} else {
#
#			# Guess using the most commonly mapped capability/technology
#			my @list = sort {$guess{$ci_solution_name}{CAPABILITY}{$a} <=> $guess{$ci_solution_name}{CAPABILITY}{$b}} keys %{$guess{$ci_solution_name}{CAPABILITY}};
#			#foreach my $l (@list) {
#			#	print "$l was $guess{$ci_solution_name}{CAPABILITY}{$l}\n";
#			#}
#			my $most_used = $list[-1];
#			my ($cap, $tech) = (split(/~~~/, $most_used))[0,1];
#
#			print "$ci_solution_name mapped (via guess) to Capability $cap and Tech $tech\n";
#			$ci_taxonomy{$ci_solution_name}{CAPABILITY} = $cap;
#			$ci_taxonomy{$ci_solution_name}{TECHNOLOGY} = $tech;
#		}
#
#	}

	return %ci_taxonomy;

}

sub jsonMessage {
		my ($result) = @_;
		my $json_total = JSON->new->allow_nonref;
	  my $json_ref = $json_total->pretty->encode($result);
		return $json_ref;
}

sub build_taxonomy
{
	my ($taxonomy_mapping) = @_;

	my @ci_taxonomy;

	foreach my $index (sort {$a <=> $b} keys %{$taxonomy_mapping}) {
		my $node_app = $taxonomy_mapping->{$index}{NODE_APP};
		my $node_group = $taxonomy_mapping->{$index}{NODE_GROUP};
		my $ci_solution_name = $taxonomy_mapping->{$index}{CI_TECH};
		my $tax_cap = $taxonomy_mapping->{$index}{TAX_CAP};
		my $tax_tech = $taxonomy_mapping->{$index}{TAX_TECH};

		my $org = "ITO";
		$org = "EAO" if ($tax_cap =~ /eao/i);


		my %x;

		foreach my $attrib (keys %{$taxonomy_mapping->{$index}}){
			$x{$ci_solution_name}{$node_app}{$node_group}{$org}{$attrib} = $taxonomy_mapping->{$index}{$attrib};
		}
		#$x{$ci_solution_name}{$node_app}{$node_group}{$org}{TAX_CAP} = $taxonomy_mapping->{$index}{TAX_CAP};
		#$x{$ci_solution_name}{$node_app}{$node_group}{$org}{TAX_TECH} = $taxonomy_mapping->{$index}{TAX_TECH};
		#$x{$ci_solution_name}{$node_app}{$node_group}{$org}{BACKUP_FORMULA} = $taxonomy_mapping->{$index}{BACKUP_FORMULA};
		#$x{$ci_solution_name}{$node_app}{$node_group}{$org}{BACKUP_FORMULA} = $taxonomy_mapping->{$index}{BACKUP_FORMULA};


		push @ci_taxonomy, \%x;
		#$ci_taxonomy{$ci_solution_name}{$node_app}{$node_group}{$org}{TAX_CAP} = $taxonomy_mapping->{$index}{TAX_CAP};
		#$ci_taxonomy{$ci_solution_name}{$node_app}{$node_group}{$org}{TAX_TECH} = $taxonomy_mapping->{$index}{TAX_TECH};
		#$ci_taxonomy{$ci_solution_name}{$node_app}{$node_group}{$org}{BACKUP_FORMULA} = $taxonomy_mapping->{$index}{BACKUP_FORMULA};

	}

	return @ci_taxonomy;
}



sub get_country_code
{
	my ($code) = @_;

	my %codes = ("US" => "United States",
		  "AF" => "Afghanistan",
		  "AL" => "Albania",
		  "DZ" => "Algeria",
		  "AS" => "American Samoa",
		  "AD" => "Andorra",
		  "AO" => "Angola",
		  "AI" => "Anguilla",
		  "AQ" => "Antarctica",
		  "AG" => "Antigua and Barbuda",
		  "AR" => "Argentina",
		  "AM" => "Armenia",
		  "AW" => "Aruba",
		  "AU" => "Australia",
		  "AT" => "Austria",
		  "AZ" => "Azerbaijan",
		  "BS" => "Bahamas",
		  "BH" => "Bahrain",
		  "BD" => "Bangladesh",
		  "BB" => "Barbados",
		  "BY" => "Belarus",
		  "BE" => "Belgium",
		  "BZ" => "Belize",
		  "BJ" => "Benin",
		  "BM" => "Bermuda",
		  "BT" => "Bhutan",
		  "BO" => "Bolivia",
		  "BA" => "Bosnia and Herzegovina",
		  "BW" => "Botswana",
		  "BV" => "Bouvet Island",
		  "BR" => "Brazil",
		  "IO" => "British Indian Ocean Territory",
		  "BN" => "Brunei Darussalam",
		  "BG" => "Bulgaria",
		  "BF" => "Burkina Faso",
		  "BI" => "Burundi",
		  "KH" => "Cambodia",
		  "CM" => "Cameroon",
		  "CA" => "Canada",
		  "CV" => "Cape Verde",
		  "KY" => "Cayman Islands",
		  "CF" => "Central African Republic",
		  "TD" => "Chad",
		  "CL" => "Chile",
		  "CN" => "China",
		  "CX" => "Christmas Island",
		  "CC" => "Cocos (Keeling) Islands",
		  "CO" => "Colombia",
		  "KM" => "Comoros",
		  "CD" => "Congo, the Democratic Republic of the",
		  "CG" => "Congo",
		  "CK" => "Cook Islands",
		  "CR" => "Costa Rica",
		  "CI" => "Cote d'Ivoire",
		  "HR" => "Croatia",
		  "CU" => "Cuba",
		  "CY" => "Cyprus",
		  "CZ" => "Czech Republic",
		  "DK" => "Denmark",
		  "DJ" => "Djibouti",
		  "DM" => "Dominica",
		  "DO" => "Dominican Republic",
		  "EC" => "Ecuador",
		  "EG" => "Egypt",
		  "SV" => "El Salvador",
		  "GQ" => "Equatorial Guinea",
		  "ER" => "Eritrea",
		  "EE" => "Estonia",
		  "ET" => "Ethiopia",
		  "FK" => "Falkland Islands (Malvinas)",
		  "FO" => "Faroe Islands",
		  "FJ" => "Fiji",
		  "FI" => "Finland",
		  "FR" => "France",
		  "GF" => "French Guiana",
		  "PF" => "French Polynesia",
		  "TF" => "French Southern Territories",
		  "GA" => "Gabon",
		  "GM" => "Gambia",
		  "GE" => "Georgia",
		  "DE" => "Germany",
		  "GH" => "Ghana",
		  "GI" => "Gibraltar",
		  "GR" => "Greece",
		  "GL" => "Greenland",
		  "GD" => "Grenada",
		  "GP" => "Guadeloupe",
		  "GU" => "Guam",
		  "GT" => "Guatemala",
		  "GG" => "Guernsey",
		  "GW" => "Guinea-Bissau",
		  "GN" => "Guinea",
		  "GY" => "Guyana",
		  "HT" => "Haiti",
		  "HM" => "Heard Island and McDonald Islands",
		  "VA" => "Holy See (Vatican City State)",
		  "HN" => "Honduras",
		  "HK" => "Hong Kong",
		  "HU" => "Hungary",
		  "IS" => "Iceland",
		  "IN" => "India",
		  "ID" => "Indonesia",
		  "IR" => "Iran, Islamic Republic of",
		  "IQ" => "Iraq",
		  "IE" => "Ireland",
		  "IM" => "Isle of Man",
		  "IL" => "Israel",
		  "IT" => "Italy",
		  "JM" => "Jamaica",
		  "JC" => "Jason C. Rochon",
		  "JP" => "Japan",
		  "JE" => "Jersey",
		  "JO" => "Jordan",
		  "KZ" => "Kazakhstan",
		  "KE" => "Kenya",
		  "KI" => "Kiribati",
		  "KP" => "Korea, Democratic People's Republic of",
		  "KR" => "Korea, Republic of",
		  "KW" => "Kuwait",
		  "KG" => "Kyrgyzstan",
		  "LA" => "Lao People's Democratic Republic",
		  "LV" => "Latvia",
		  "LB" => "Lebanon",
		  "LS" => "Lesotho",
		  "LR" => "Liberia",
		  "LY" => "Libyan Arab Jamahiriya",
		  "LI" => "Liechtenstein",
		  "LT" => "Lithuania",
		  "LU" => "Luxembourg",
		  "MO" => "Macao",
		  "MK" => "Macedonia, the former Yugoslav Republic of",
		  "MG" => "Madagascar",
		  "MW" => "Malawi",
		  "MY" => "Malaysia",
		  "MV" => "Maldives",
		  "ML" => "Mali",
		  "MT" => "Malta",
		  "MH" => "Marshall Islands",
		  "MQ" => "Martinique",
		  "MR" => "Mauritania",
		  "MU" => "Mauritius",
		  "YT" => "Mayotte",
		  "MX" => "Mexico",
		  "FM" => "Micronesia, Federated States of",
		  "MD" => "Moldova, Republic of",
		  "MC" => "Monaco",
		  "MN" => "Mongolia",
		  "ME" => "Montenegro",
		  "MS" => "Montserrat",
		  "MA" => "Morocco",
		  "MZ" => "Mozambique",
		  "MM" => "Myanmar",
		  "NA" => "Namibia",
		  "NR" => "Nauru",
		  "NP" => "Nepal",
		  "AN" => "Netherlands Antilles",
		  "NL" => "Netherlands",
		  "NC" => "New Caledonia",
		  "NZ" => "New Zealand",
		  "NI" => "Nicaragua",
		  "NE" => "Niger",
		  "NG" => "Nigeria",
		  "NU" => "Niue",
		  "NF" => "Norfolk Island",
		  "MP" => "Northern Mariana Islands",
		  "NO" => "Norway",
		  "OM" => "Oman",
		  "PK" => "Pakistan",
		  "PW" => "Palau",
		  "PS" => "Palestinian Territory, Occupied",
		  "PA" => "Panama",
		  "PG" => "Papua New Guinea",
		  "PY" => "Paraguay",
		  "PE" => "Peru",
		  "PH" => "Philippines",
		  "PN" => "Pitcairn",
		  "PL" => "Poland",
		  "PT" => "Portugal",
		  "PR" => "Puerto Rico",
		  "QA" => "Qatar",
		  "RE" => "Reunion",
		  "RO" => "Romania",
		  "RU" => "Russian Federation",
		  "RW" => "Rwanda",
		  "BL" => "Saint Barthelemy",
		  "SH" => "Saint Helena",
		  "KN" => "Saint Kitts and Nevis",
		  "LC" => "Saint Lucia",
		  "MF" => "Saint Martin (French part)",
		  "PM" => "Saint Pierre and Miquelon",
		  "VC" => "Saint Vincent and the Grenadines",
		  "WS" => "Samoa",
		  "SM" => "San Marino",
		  "ST" => "Sao Tome and Principe",
		  "SA" => "Saudi Arabia",
		  "SN" => "Senegal",
		  "RS" => "Serbia",
		  "SC" => "Seychelles",
		  "SL" => "Sierra Leone",
		  "SG" => "Singapore",
		  "SK" => "Slovakia",
		  "SI" => "Slovenia",
		  "SB" => "Solomon Islands",
		  "SO" => "Somalia",
		  "ZA" => "South Africa",
		  "GS" => "South Georgia and the South Sandwich Islands",
		  "ES" => "Spain",
		  "LK" => "Sri Lanka",
		  "SD" => "Sudan",
		  "SR" => "Suriname",
		  "SJ" => "Svalbard and Jan Mayen",
		  "SZ" => "Swaziland",
		  "SE" => "Sweden",
		  "CH" => "Switzerland",
		  "SY" => "Syrian Arab Republic",
		  "TW" => "Taiwan, Province of China",
		  "TJ" => "Tajikistan",
		  "TZ" => "Tanzania, United Republic of",
		  "TH" => "Thailand",
		  "TL" => "Timor-Leste",
		  "TG" => "Togo",
		  "TK" => "Tokelau",
		  "TO" => "Tonga",
		  "TT" => "Trinidad and Tobago",
		  "TN" => "Tunisia",
		  "TR" => "Turkey",
		  "TM" => "Turkmenistan",
		  "TC" => "Turks and Caicos Islands",
		  "TV" => "Tuvalu",
		  "UG" => "Uganda",
		  "UA" => "Ukraine",
		  "AE" => "United Arab Emirates",
		  "GB" => "United Kingdom",
		  "UM" => "United States Minor Outlying Islands",
		  "US" => "United States",
		  "UY" => "Uruguay",
		  "UZ" => "Uzbekistan",
		  "VU" => "Vanuatu",
		  "VE" => "Venezuela",
		  "VN" => "Viet Nam",
		  "VG" => "Virgin Islands, British",
		  "VI" => "Virgin Islands, U.S.",
		  "WF" => "Wallis and Futuna",
		  "EH" => "Western Sahara",
		  "YE" => "Yemen",
		  "ZM" => "Zambia",
		  "ZW" => "Zimbabwe"
    );

    return $codes{$code};
}

sub get_country_name
{
	my ($country) = @_;

	my %countries = ("afghanistan" => "AF",
		"albania" => "AL",
		"algeria" => "DZ",
		"american samoa" => "AS",
		"andorra" => "AD",
		"angola" => "AO",
		"anguilla" => "AI",
		"antarctica" => "AQ",
		"antigua and barbuda" => "AG",
		"argentina" => "AR",
		"armenia" => "AM",
		"aruba" => "AW",
		"australia" => "AU",
		"austria" => "AT",
		"azerbaijan" => "AZ",
		"bahamas" => "BS",
		"bahrain" => "BH",
		"bangladesh" => "BD",
		"barbados" => "BB",
		"belarus" => "BY",
		"belgium" => "BE",
		"belize" => "BZ",
		"benin" => "BJ",
		"bermuda" => "BM",
		"bhutan" => "BT",
		"bolivia" => "BO",
		"bosnia and herzegovina" => "BA",
		"botswana" => "BW",
		"bouvet island" => "BV",
		"brazil" => "BR",
		"british indian ocean territory" => "IO",
		"brunei darussalam" => "BN",
		"bulgaria" => "BG",
		"burkina faso" => "BF",
		"burundi" => "BI",
		"cambodia" => "KH",
		"cameroon" => "CM",
		"canada" => "CA",
		"cape verde" => "CV",
		"cayman islands" => "KY",
		"central african republic" => "CF",
		"chad" => "TD",
		"chile" => "CL",
		"china" => "CN",
		"christmas island" => "CX",
		"cocos (keeling) islands" => "CC",
		"colombia" => "CO",
		"comoros" => "KM",
		"congo" => "CG",
		"congo, the democratic republic of the" => "CD",
		"cook islands" => "CK",
		"costa rica" => "CR",
		"cote d'ivoire" => "CI",
		"croatia" => "HR",
		"cuba" => "CU",
		"cyprus" => "CY",
		"czech republic" => "CZ",
		"denmark" => "DK",
		"djibouti" => "DJ",
		"dominica" => "DM",
		"dominican republic" => "DO",
		"ecuador" => "EC",
		"egypt" => "EG",
		"el salvador" => "SV",
		"equatorial guinea" => "GQ",
		"eritrea" => "ER",
		"estonia" => "EE",
		"ethiopia" => "ET",
		"falkland islands (malvinas)" => "FK",
		"faroe islands" => "FO",
		"fiji" => "FJ",
		"finland" => "FI",
		"france" => "FR",
		"french guiana" => "GF",
		"french polynesia" => "PF",
		"french southern territories" => "TF",
		"gabon" => "GA",
		"gambia" => "GM",
		"georgia" => "GE",
		"germany" => "DE",
		"ghana" => "GH",
		"gibraltar" => "GI",
		"greece" => "GR",
		"greenland" => "GL",
		"grenada" => "GD",
		"guadeloupe" => "GP",
		"guam" => "GU",
		"guatemala" => "GT",
		"guernsey" => "GG",
		"guinea" => "GN",
		"guinea-bissau" => "GW",
		"guyana" => "GY",
		"haiti" => "HT",
		"heard island and mcdonald islands" => "HM",
		"holy see (vatican city state)" => "VA",
		"honduras" => "HN",
		"hong kong" => "HK",
		"hungary" => "HU",
		"iceland" => "IS",
		"india" => "IN",
		"indonesia" => "ID",
		"iran, islamic republic of" => "IR",
		"iraq" => "IQ",
		"ireland" => "IE",
		"isle of man" => "IM",
		"israel" => "IL",
		"italy" => "IT",
		"jamaica" => "JM",
		"japan" => "JP",
		"jason c. rochon" => "JC",
		"jersey" => "JE",
		"jordan" => "JO",
		"kazakhstan" => "KZ",
		"kenya" => "KE",
		"kiribati" => "KI",
		"korea, democratic people's republic of" => "KP",
		"korea, republic of" => "KR",
		"kuwait" => "KW",
		"kyrgyzstan" => "KG",
		"lao people's democratic republic" => "LA",
		"latvia" => "LV",
		"lebanon" => "LB",
		"lesotho" => "LS",
		"liberia" => "LR",
		"libyan arab jamahiriya" => "LY",
		"liechtenstein" => "LI",
		"lithuania" => "LT",
		"luxembourg" => "LU",
		"macao" => "MO",
		"macedonia, the former yugoslav republic of" => "MK",
		"madagascar" => "MG",
		"malawi" => "MW",
		"malaysia" => "MY",
		"maldives" => "MV",
		"mali" => "ML",
		"malta" => "MT",
		"marshall islands" => "MH",
		"martinique" => "MQ",
		"mauritania" => "MR",
		"mauritius" => "MU",
		"mayotte" => "YT",
		"mexico" => "MX",
		"micronesia, federated states of" => "FM",
		"moldova, republic of" => "MD",
		"monaco" => "MC",
		"mongolia" => "MN",
		"montenegro" => "ME",
		"montserrat" => "MS",
		"morocco" => "MA",
		"mozambique" => "MZ",
		"myanmar" => "MM",
		"namibia" => "NA",
		"nauru" => "NR",
		"nepal" => "NP",
		"netherlands" => "NL",
		"netherlands antilles" => "AN",
		"new caledonia" => "NC",
		"new zealand" => "NZ",
		"nicaragua" => "NI",
		"niger" => "NE",
		"nigeria" => "NG",
		"niue" => "NU",
		"norfolk island" => "NF",
		"northern mariana islands" => "MP",
		"norway" => "NO",
		"oman" => "OM",
		"pakistan" => "PK",
		"palau" => "PW",
		"palestinian territory, occupied" => "PS",
		"panama" => "PA",
		"papua new guinea" => "PG",
		"paraguay" => "PY",
		"peru" => "PE",
		"philippines" => "PH",
		"pitcairn" => "PN",
		"poland" => "PL",
		"portugal" => "PT",
		"puerto rico" => "PR",
		"qatar" => "QA",
		"reunion" => "RE",
		"romania" => "RO",
		"russian federation" => "RU",
		"rwanda" => "RW",
		"saint barthelemy" => "BL",
		"saint helena" => "SH",
		"saint kitts and nevis" => "KN",
		"saint lucia" => "LC",
		"saint martin (french part)" => "MF",
		"saint pierre and miquelon" => "PM",
		"saint vincent and the grenadines" => "VC",
		"samoa" => "WS",
		"san marino" => "SM",
		"sao tome and principe" => "ST",
		"saudi arabia" => "SA",
		"senegal" => "SN",
		"serbia" => "RS",
		"seychelles" => "SC",
		"sierra leone" => "SL",
		"singapore" => "SG",
		"slovakia" => "SK",
		"slovenia" => "SI",
		"solomon islands" => "SB",
		"somalia" => "SO",
		"south africa" => "ZA",
		"south georgia and the south sandwich islands" => "GS",
		"spain" => "ES",
		"sri lanka" => "LK",
		"sudan" => "SD",
		"suriname" => "SR",
		"svalbard and jan mayen" => "SJ",
		"swaziland" => "SZ",
		"sweden" => "SE",
		"switzerland" => "CH",
		"syrian arab republic" => "SY",
		"taiwan, province of china" => "TW",
		"tajikistan" => "TJ",
		"tanzania, united republic of" => "TZ",
		"thailand" => "TH",
		"timor-leste" => "TL",
		"togo" => "TG",
		"tokelau" => "TK",
		"tonga" => "TO",
		"trinidad and tobago" => "TT",
		"tunisia" => "TN",
		"turkey" => "TR",
		"turkmenistan" => "TM",
		"turks and caicos islands" => "TC",
		"tuvalu" => "TV",
		"uganda" => "UG",
		"ukraine" => "UA",
		"united arab emirates" => "AE",
		"united kingdom" => "GB",
		"united states" => "US",
		"united states minor outlying islands" => "UM",
		"uruguay" => "UY",
		"uzbekistan" => "UZ",
		"vanuatu" => "VU",
		"venezuela" => "VE",
		"viet nam" => "VN",
		"virgin islands, british" => "VG",
		"virgin islands, u.s." => "VI",
		"wallis and futuna" => "WF",
		"western sahara" => "EH",
		"yemen" => "YE",
		"zambia" => "ZM",
		"zimbabwe" => "ZW"
    );

	$country = lc($country);
	return $countries{$country};
}



sub filter_people
{
   my ($people) = @_;

   my (%filtered_people);

   my %allocation_rules = ('wintel' => ['wintel:all:-active directory,-virtulisation:wintel', 'wintel:none:+active directory:active directory', 'wintel:none:+virtualisation:hypervisors'],
                           'midrange' => ['midrange:all::midrange','midrange:all:-as400,-tandem:unix-linux', 'midrange:none:+as400:as400', 'midrange:none:+tandem:tandem'],
                           'database' => ['database:all::database','database:none:+oracle:oracle','database:none:+sql:mssql','database:all:-oracle,-sql:db_other'],
                           'messaging & collaboration' => ['messaging & collaboration:all::mobility and workplace services','messaging & collaboration:none:+messaging:messaging', 'messaging & collaboration:none:+collaboration:collaboration', 'messaging & collaboration:all:-messaging,-collaboration:messaging-other'],
                           'software management' => ['software management:all::mobility and workplace services', 'software management:none:+pc patching:pc patching', 'software management:all:-pc patching:software-other']);


   foreach my $c (keys %{$people}) {

      foreach my $ca (keys %{$people->{$c}}) {

         if (defined($allocation_rules{$ca})) {

            my %cap;

            foreach my $rule (@{$allocation_rules{$ca}}) {
               #print "$ca has an allocation rule : $rule\n";

               if ($rule =~ /^(.*?)\:(all|none)\:(.*?):(.*?)$/) {
                  my $cap_str = $1;
                  my $scope_str = $2;
                  my $sub_cap = $3;
                  my $target_cap = $4;

         	      if ($scope_str=~/all/i) {
                     $cap{INCLUDE_ALL} = "all";
                  }
                  if ($scope_str=~/none/i) {
                     $cap{INCLUDE_ALL} = "none";
                  }

                  foreach my $x (split(/\,/,$sub_cap)) {

                     if ($scope_str=~/all/i and $x =~ /\-(.*)/) {
                         $cap{EXCLUDE} .= "$1:";
                     }
                     if ($scope_str=~/none/i and $x =~ /\+(.*)/) {
                        $cap{INCLUDE} .= "$1:";
                     }
                  }

                  foreach my $ty (keys %{$people->{$c}{$ca}}) {

      	            foreach my $name (keys %{$people->{$c}{$ca}{$ty}{PERSON}}) {

      	               my $sub_capability = $people->{$c}{$ca}{$ty}{PERSON}{$name}{SUB_CAPABILITY};

      	               if ($cap{INCLUDE_ALL} ne "") {
      	                  if (($cap{INCLUDE_ALL} =~ /all/i and $cap{EXCLUDE} !~ /$sub_capability/) or ($cap{INCLUDE_ALL} =~ /none/i and $cap{INCLUDE} =~ /$sub_capability/)) {
      	                     #print "$c Including $name for $target_cap because of allocation rule $rule<br>" if ($c =~ /cba/i and $ca=~/act/i);
                              $filtered_people{$c}{$target_cap}{$ty}{PERSON}{$name} = $people->{$c}{$ca}{$ty}{PERSON}{$name};
         	               } else {
         	                  #print "$c Excluding $name from $target_cap because of allocation rule $rule (SUB: $sub_capability)<br>" if ($c =~ /cba/i);
         	               }
      	               }
      	            }
      	         }

               }
            }

         } else {

            # no rules - so straight copy
           $filtered_people{$c}{$ca} = $people->{$c}{$ca};

         }


	   }
	}

	return \%filtered_people;

}

sub get_backup_rollup {
	my ($customer, $platform,$type, $backup_report) = @_;

	my $no_backup=0;
	my $no_date=0;
	my $good_backup=0;
	my $amber_backup=0;
	my $orange_backup=0;
	my $red_backup=0;
	my $etp=0;

	my @cap = ('wintel','midrange');
	foreach my $capability (@cap) {
  	eval {if (scalar @{$backup_report->{good_backup}{$customer}{$capability}{prd}} > 0) { $good_backup += scalar @{$backup_report->{good_backup}{$customer}{$capability}{prd}}; } };
  	#eval { if (scalar @{$backup_report->{good_backup}{$customer}{$capability}{nonprd}} > 0) { $good_backup += scalar @{$backup_report->{good_backup}{$customer}{$capability}{nonprd}}; } };

  	eval {if (scalar @{$backup_report->{amber_backup}{$customer}{$capability}{prd}} > 0) { $amber_backup += scalar @{$backup_report->{amber_backup}{$customer}{$capability}{prd}}; } };
  	#eval {if (scalar @{$backup_report->{amber_backup}{$customer}{$capability}{nonprd}} > 0) { $amber_backup += scalar @{$backup_report->{amber_backup}{$customer}{$capability}{nonprd}}; } };

  	eval {if (scalar @{$backup_report->{orange_backup}{$customer}{$capability}{prd}} > 0) { $orange_backup += scalar @{$backup_report->{orange_backup}{$customer}{$capability}{prd}}; } };
  	#eval {if (scalar @{$backup_report->{orange_backup}{$customer}{$capability}{nonprd}}) { $orange_backup += scalar @{$backup_report->{orange_backup}{$customer}{$capability}{nonprd}}; } };

  	eval {if (scalar @{$backup_report->{red_backup}{$customer}{$capability}{prd}} > 0) { $red_backup += scalar @{$backup_report->{red_backup}{$customer}{$capability}{prd}}; } };
  	#eval {if (scalar @{$backup_report->{red_backup}{$customer}{$capability}{nonprd}} > 0) { $red_backup += scalar @{$backup_report->{red_backup}{$customer}{$capability}{nonprd}}; } };

  	eval {if (scalar @{$backup_report->{no_backup}{$customer}{$capability}{prd}} > 0) { $no_backup += scalar @{$backup_report->{no_backup}{$customer}{$capability}{prd}}; } };
  	#eval {if (scalar @{$backup_report->{no_backup}{$customer}{$capability}{nonprd}} > 0) { $no_backup += scalar @{$backup_report->{no_backup}{$customer}{$capability}{nonprd}}; } };

  	eval {if (scalar @{$backup_report->{no_date}{$customer}{$capability}{prd}} > 0) { $no_date += scalar @{$backup_report->{no_date}{$customer}{$capability}{prd}}; } };
  	#eval {if (scalar @{$backup_report->{no_date}{$customer}{$capability}{nonprd}} > 0) { $no_date += scalar @{$backup_report->{no_date}{$customer}{$capability}{nonprd}}; } };

  	eval {if (scalar @{$backup_report->{'backup_not_required'}{$customer}{$capability}{prd}} > 0) { $etp += scalar @{$backup_report->{'backup_not_required'}{$customer}{$capability}{prd}}; } };
  	#eval {if (scalar @{$backup_report->{'backup_not_required'}{$customer}{$capability}{nonprd}} > 0) { $etp += scalar @{$backup_report->{'backup_not_required'}{$customer}{$capability}{nonprd}}; } };
	}
  my %x = (no_backup => $no_backup,no_date => $no_date, good_backup => $good_backup,
  amber_backup => $amber_backup, orange_backup => $orange_backup, red_backup => $red_backup, etp => $etp);
  return \%x;

}

sub get_people_kpi {
	my ($customer, $capability, $people, $total_ci_count) = @_;
	my ($operations_kpi,$people_list, $sub_capability);
	my %cap;

	if ($total_ci_count eq "") { $total_ci_count =0; }

	my $total_allocation = 0;

	if (exists($people->{$customer})) {
		if (exists($people->{$customer}{$capability})) {

      	foreach my $name (keys %{$people->{$customer}{$capability}{RUN}{PERSON}}) {
      	   $total_allocation += $people->{$customer}{$capability}{RUN}{PERSON}{$name}{TOTAL_ALLOCATION};
      	}

      	foreach my $name (keys %{$people->{$customer}{$capability}{LIFECYCLE}{PERSON}}) {
      	   $total_allocation += $people->{$customer}{$capability}{LIFECYCLE}{PERSON}{$name}{TOTAL_ALLOCATION};
      	}
	   }
	}
	if ($total_allocation > 0 ) {
	   $operations_kpi = sprintf "%0.3f",$total_ci_count / $total_allocation;
	}

#	if ($people->{$customer}{$capability}{RUN}{SHORE}{TOTAL} + $people->{$customer}{$capability}{LIFECYCLE}{SHORE}{TOTAL} > 0) {
#	   $operations_kpi = sprintf "%0.2f",$total_ci_count / ($people->{$customer}{$capability}{RUN}{SHORE}{TOTAL} + $people->{$customer}{$capability}{LIFECYCLE}{SHORE}{TOTAL});
#	   $people_list = $people->{$customer}{$capability}{RUN}{SHORE}{TOTAL} + $people->{$customer}{$capability}{LIFECYCLE}{SHORE}{TOTAL};
#	} else {
#	   $operations_kpi = "0";
#	   $people_list = "0";
#	}
#	print "CUSTOMER : $customer P: $capability  : INCLUDE = $cap{INCLUDE} EXCLUDE = $cap{EXCLUDE} KPI = ". $operations_kpi * 160 ." People = $total_allocation<br>";

	#return ($operations_kpi,$people_list);
	#print "CUSTOMER: $customer : $capability KPI = ". $operations_kpi * 160 ." People = $total_allocation<br>";
	return ($operations_kpi,$total_allocation);

}
sub get_kpe_list {
   my ($sp_customer,$kpe_list) = @_;

   my %x;

   foreach my $kpe (keys %{$kpe_list->{$sp_customer}}) {
   	foreach my $node (keys 	%{$kpe_list->{$sp_customer}{$kpe}}) {
   		push @{$x{$node}{KPE_LIST}}, $kpe;
   	}
   }

   return \%x;
}


sub get_patch_compliance_customer
{
   my ($customer,$patch_compliance,$win_patch,$win_os_patch,$capability,$type,$account_reg) =@_;
   my %x;
   my %y;
   my %result;
   my ($AT_MET_ESIS,$P30_MET_ESIS,$AT_NON_OPT_PATCHES,$P30_NON_OPT_PATCHES,$AT_INSIDE_ESIS);
   my $compliant=0;
   my $total_eos=0;
   my $total_srv=0;

   my $os_compliant=0;
   my $os_total_srv=0;
   my $os_non_compliant=0;
   my $os_old=0;

	$AT_MET_ESIS =0;
	$P30_MET_ESIS=0;
	$AT_NON_OPT_PATCHES=0;
	$P30_NON_OPT_PATCHES=0;
	$AT_INSIDE_ESIS=0;

	if (defined($patch_compliance->{$customer}{$capability})) {

		foreach my $z (@{$patch_compliance->{$customer}{$capability}{$type}}) {
			$AT_MET_ESIS += $z->{AT_MET_ESIS};
			$P30_MET_ESIS += $z->{P30_MET_ESIS};
			$AT_NON_OPT_PATCHES += $z->{TOTAL_NON_OPT_PATCHES};
			$P30_NON_OPT_PATCHES += $z->{P30_TOTAL_NON_OPT_PATCHES};
			$AT_INSIDE_ESIS += $z->{AT_INSIDE_ESIS};
			##New Definition
			if ($z->{node}) {

					if ($win_patch->{"$z->{node}"}{COMPLIANT} =~ /y/i) {
						$compliant++;
					}

  				if ($win_patch->{"$z->{node}"}{EOS_EXCEEDED} =~ /n/i) {
  						$total_eos++;
  						$total_srv++;
  				}

  				if ($win_patch->{"$z->{node}"}{EOS_EXCEEDED} =~ /y/i) {
  						$total_srv++;
  				}

  				##OS Patch
  				if ($win_os_patch->{"$z->{node}"}{COMPLIANT} =~ /^compliant/i) {
						  $os_compliant++;
						  $os_total_srv++;
					} elsif ($win_os_patch->{"$z->{node}"}{COMPLIANT} =~ /^not/i) {
						 $os_total_srv++;
						 $os_non_compliant++;
					} elsif ($win_os_patch->{"$z->{node}"}{COMPLIANT} =~ /too old/i) {
						 $os_total_srv++;
						 $os_old++;
						 $os_total_srv++;
					}

		  }

		}
		if ($AT_MET_ESIS ne "" and $AT_NON_OPT_PATCHES > 0) {
			$x{$customer} = sprintf "%0.1f", ( ($AT_MET_ESIS + $AT_INSIDE_ESIS) / $AT_NON_OPT_PATCHES) * 100;
	  }

	  if ($P30_MET_ESIS ne "" and $P30_NON_OPT_PATCHES > 0) {
			$y{$customer} = sprintf "%0.1f", $P30_MET_ESIS / $P30_NON_OPT_PATCHES * 100;
	   }

	    $result{COMPLIANCE} = sprintf "%0.1f", eval { $compliant / $total_srv * 100; };
			$result{TOTAL_EOS} = $total_eos;
			$result{TOTAL_SERVER} = $total_srv;
			$result{TOTAL_COMPLIANT} = $compliant;

			$result{OS_COMPLIANCE} = sprintf "%0.1f", eval { $os_compliant / $os_total_srv * 100; };
			$result{OS_TOTAL_SERVER} = $os_total_srv;
			$result{OS_TOTAL_COMPLIANT} = $os_compliant;

	}

  	my @data_at =  sort { $x{$a} <=> $x{$b} } keys %x;
  	my @data_p30 =  sort { $y{$a} <=> $y{$b} } keys %y;
  	#print Dumper(\%x);
  	return (\%x,\%result,\%y,\@data_at,\@data_p30);
}


sub get_patch_compliance_unix_customer
{
   my ($customer,$esis,$patch,$capability,$type,$account_reg) =@_;
   my %x;
   my $compliant=0;
   my $total_eos=0;
   my $total_srv=0;
   if (defined($esis->{$customer}{$capability})) {

		foreach my $z (@{$esis->{$customer}{$capability}{$type}}) {
			if ($z->{node}) {
				if ($patch->{$z->{node}}{COMPLIANT} =~ /y|e/i) {
					$compliant++;
				}

  				if ($patch->{$z->{node}}{EOS_EXCEEDED} =~ /n/i) {
  						$total_eos++;
  						$total_srv++;
  				}

  				if ($patch->{$z->{node}}{EOS_EXCEEDED} =~ /y/i) {
  						$total_srv++;
  				}
		   }
		}
		$x{COMPLIANCE} = sprintf "%0.1f", eval { $compliant / $total_eos * 100; };
			$x{TOTAL_EOS} = $total_eos;
			$x{TOTAL_SERVER} = $total_srv;
			#print Dumper(\%x);
   }

  	return (\%x);
}


sub date_to_tick
{
	my ($date_str, $tz) = @_;

	my $time;
	if ($date_str =~ /(\d{4})\-(\d{2})\-(\d{2}) (\d{2})\:(\d{2})/) {
		#$time = POSIX::mktime(0,$5,$4,$3,$2-1,$1-1900);
		$time = timelocal(0,$5,$4,$3,$2-1,$1);
	}

	if ($tz =~ /gmt-(\d+)/) {
		$time = $time - ($1 * 3600);
	}

	if ($tz =~ /gmt+(\d+)/) {
		$time = $time + ($1 * 3600);
	}
	return $time;
}


sub get_eol_dataprotector
{
   my ($customer, $capability, $when, $bkpsrv, $bkpver, $type) = @_;

   my $count;
   my %x;
   #if (scalar @{$bkpsrv->{$customer}{"dataprotector server"}} > 0) {
      foreach my $server (@{$bkpsrv->{$customer}{"dataprotector server"}}) {
          foreach my $eol_pattern (keys %eol_dataprotector) {
             next if ($eol_dataprotector{$eol_pattern} != $when);
             if ( $bkpver->{$server}{VERSION} =~ /$eol_pattern/i) {
                $count++;
                $x{$server}{DATAPROTECTOR} = $bkpver->{$server}{VERSION};
             }
          }
      }
   #}
   #print "$customer,$count,$when\n";
   if ($type =~ /count/i) {
   		return $count;
   } else {
   		return \%x;
   }
}


sub get_eol_os
{
   my ($customer, $capability, $when, $eol, $afg) = @_;

   my ($count);

   $count = 0;

   if (defined($eol->{$customer})) {
      if ($capability =~/wintel/i) {

         foreach my $x (keys %{$eol->{$customer}}) {
          foreach my $eol_pattern (keys %eol_wintel_cfg) {
             next if ($eol_wintel_cfg{$eol_pattern} != $when);
             if ( $x =~ /$eol_pattern/i) {
                $count += $eol->{$customer}{$x};
             }
          }
         }
      }

      if ($capability =~/midrange/i) {

         foreach my $x (keys %{$eol->{$customer}}) {
          foreach my $eol_pattern (keys %eol_midrange_cfg) {
             next if ($eol_midrange_cfg{$eol_pattern} != $when);
             if ( $x =~ /$eol_pattern/i) {
                $count += $eol->{$customer}{$x};
             }
          }
         }
      }
   } elsif (defined($afg->{$customer})) {

      if ($when == 12) {
         $count = $afg->{$customer}{$capability}{EOL_YEAR};
      }
      if ($when == 0) {
         $count = $afg->{$customer}{$capability}{EOL_NOW};
      }
   } else {
      $count = 0;
   }

   return $count;
}


###############################################################################
# get_current_time
#
# inputs
#     none
#
# returns
#     $time_str - current time in YYYY-MM-DD format
#
# Algorithm
#  uses localtime to format a time string
###############################################################################
sub get_current_time
{
   my ($min,$hour,$mday,$mon,$year);

   ($mon,$year,$mday,$hour,$min) = (localtime(time))[4,5,3,2,1];

   $mon++;

   if ($mon < 10) { $mon = "0".$mon; }
   if ($mday < 10) { $mday = "0".$mday; }
   if ($hour < 10) { $hour = "0".$hour; }
   if ($min < 10) { $min = "0".$min; }
   #2015-04-10 10:13:09
   my $time_str = sprintf "%s-%s-%s %s:%s", $year+1900,$mon,$mday,$hour,$min;

   return $time_str;
}


###############################################################################
# get_current_date
#
# inputs
#     none
#
# returns
#     $time_str - current time in YYYY-MM-DD format
#
# Algorithm
#  uses localtime to format a time string
###############################################################################
sub get_current_date
{
   my ($min,$hour,$mday,$mon,$year);

   ($mon,$year,$mday) = (localtime(time))[4,5,3];

   $mon++;

   if ($mon < 10) { $mon = "0".$mon; }
   if ($mday < 10) { $mday = "0".$mday; }

   #2015-04-10 10:13:09
   my $time_str = sprintf "%s-%s-%s", $year+1900,$mon,$mday;

   return $time_str;
}


sub get_server_baseline
{
   my ($sp_customer, $capability,$type, $total_cilist, $afg_cilist) = @_;


   my $total_count=0;
   my $total_all_ci=0;
   my ($virt,$virt_p,$phy,$phy_p,$audit_f,$audit_fperc);
   my ($esx, $total_with_esx);

   $virt = 0;
   $phy = 0;
   $total_all_ci = 0;
   $audit_f = 0;
   $esx = 0;
   $total_with_esx = 0;
   $total_all_ci = 0;

   if (defined($total_cilist->{$sp_customer}{lc($capability)}{$type})) {
      # For ESL Accounts
      $total_count = $total_cilist->{$sp_customer}{lc($capability)}{$type}{total_ci} || "0";
      $virt = $total_cilist->{$sp_customer}{lc($capability)}{$type}{virtual} || "0";
      $phy = $total_cilist->{$sp_customer}{lc($capability)}{$type}{physical} || "0";
      $audit_f = $total_cilist->{$sp_customer}{lc($capability)}{$type}{audit_fail} || "0";
      $total_all_ci = ($total_cilist->{$sp_customer}{lc($capability)}{all}{total_ci} + $total_all_ci);
      $esx = $total_cilist->{$sp_customer}{lc($capability)}{$type}{total_esx} || "0";
      $total_with_esx = $phy + $virt + $esx;

   } elsif (defined($afg_cilist->{lc($sp_customer)}{lc($capability)})) {
      # Dedicated Account
      if ($type eq  "prd") {
         $virt = sprintf "%d",$afg_cilist->{lc($sp_customer)}{lc($capability)}{BASELINE_VIRTUAL_SERVERS};
         $phy = sprintf "%d",$afg_cilist->{lc($sp_customer)}{lc($capability)}{BASELINE_PHYSICAL_SERVERS};
         $esx = 0;
         $total_count = $afg_cilist->{lc($sp_customer)}{lc($capability)}{BASELINE_SERVERS};
         $total_all_ci = $total_count;
         $audit_f=0;

         $total_with_esx = $phy + $virt + $esx;
         $total_with_esx = $total_count if ($total_with_esx == 0);
      }
   }

   if ($virt > 0) {		$virt_p = sprintf "%d", ($virt/$total_count) * 100;}
   else { $virt = 0; $virt_p = 0; }

   if ($phy > 0) {		$phy_p = sprintf "%d", ($phy/$total_count) * 100;}
   else { $phy = 0; $phy_p = 0; }

   if ($audit_f > 0) {		$audit_fperc = sprintf "%d", ($audit_f/$total_count) * 100;}
   else { $audit_f = 0; $audit_fperc = 0; }

   $virt = "No Data" if (defined($afg_cilist->{lc($sp_customer)}{lc($capability)}) and not defined($afg_cilist->{lc($sp_customer)}{lc($capability)}{BASELINE_VIRTUAL_SERVERS}));
   $phy = "No Data" if (defined($afg_cilist->{lc($sp_customer)}{lc($capability)}) and not defined($afg_cilist->{lc($sp_customer)}{lc($capability)}{BASELINE_PHYSICAL_SERVERS}));
   $total_count = "No Data" if (defined($afg_cilist->{lc($sp_customer)}{lc($capability)}) and not defined($afg_cilist->{lc($sp_customer)}{lc($capability)}{BASELINE_SERVERS}));
   $total_with_esx = "No Data" if ($virt =~/populate/i and $phy =~ /populate/i and $total_count=~/populate/i);


   my %x = (total_ci_count => $total_count,
            virt_ci_count=>$virt,
            virt_ci_perc=>$virt_p,
            phy_ci_count=>$phy,
            phy_ci_perc=>$phy_p,
            audit_fail=>$audit_f,
            audit_fperc => $audit_fperc,
            total_all_ci=>$total_all_ci,
            total_esx => $esx,
            total_with_esx => $total_with_esx);

   return \%x;
   #return ($total_count,$virt,$virt_p,$phy,$phy_p,$audit_f,$audit_fperc,$total_all_ci);
}

sub get_server_prod_count_by_date
{
   #date format needs to be in dd-mm-yyyy
   my ($sp_customer, $prod_date, $total_ci) = @_;
   my %list;
   my @x = split(/-/,$prod_date);
   my $prod_tick_start = POSIX::mktime(0,0,0,$x[0],$x[1]-1,$x[2]-1900);
   my $prod_tick_end = $prod_tick_start + 86400;

      foreach my $fqdn (keys %{$total_ci->{lc($sp_customer)}}) {
      	  if ( $total_ci->{lc($sp_customer)}{$fqdn}{PROD_DATE} =~ /null/i) {
      	  	$total_ci->{lc($sp_customer)}{$fqdn}{PROD_DATE} = $total_ci->{lc($sp_customer)}{$fqdn}{STATUS_CHANGE_DATE};
      	  }
      	  my @y= split(/-/, $total_ci->{lc($sp_customer)}{$fqdn}{PROD_DATE});
      	  my @z= split(/-/, $total_ci->{lc($sp_customer)}{$fqdn}{DECOMM_DATE});
      	  my $server_prod_tick=0;
      	  my $server_decomm_tick=0;

      	  my $server_prod_tick = POSIX::mktime(0,0,0,$y[2],$y[1]-1,$y[0]-1900);
      	  if ($total_ci->{lc($sp_customer)}{$fqdn}{DECOMM_DATE} =~ /^\d*/) {
      	  	$server_decomm_tick = POSIX::mktime(0,0,0,$z[2],$z[1]-1,$x[0]-1900);
      	  }

      	  if ($server_prod_tick >= $prod_tick_start and $server_prod_tick <= $prod_tick_end) {
      	  	  $list{$fqdn} = \%{$total_ci->{lc($sp_customer)}};
      	  }

      	  if ($server_decomm_tick >= $prod_tick_start and $server_decomm_tick <= $prod_tick_end) {
      	  	  delete $list{$fqdn};
      	  }

      }

      return \%list;
}

sub get_backup_infra_baseline {
  	my ($customer,$capability,$bkpsrv) = @_;
  	my $count_prd =0;
  	my $count_nonprd =0;

  	foreach my $node (sort keys %$bkpsrv) {
  		next if ($bkpsrv->{$node}{CUSTOMER} !~ /^$customer$/i);
  		if ($bkpsrv->{$node}{STATUS} =~ /in production/i) {
  			$count_prd++;
  		} else {
  			$count_nonprd++;
  		}
  	}

  	 my %x = (total_prd_bkpinfra => $count_prd, total_nonprd_bkpinfra=>$count_nonprd);
  	return (\%x);
}


sub get_db_baseline {
   my ($customer,$type,$dbeol,$afg_db,$region,$account_reg) = @_;
   my $capability="database";
   my $db_managed_instances=0;
   my $db_managed_servers=0;
   my $total_oracle_instances=0;
   my $total_oracle_servers=0;
   my $total_mssql_servers = 0;
   my $total_mssql_instances=0;
   my $total_other_instances=0;
   my $total_other_servers=0;
   my $not_in_scope=0;

		   if (defined($dbeol->{$customer}{$type}{TOTAL})) {
		      # For ESL Accounts
					 	$db_managed_instances = $dbeol->{$customer}{$type}{TOTAL};
      			$db_managed_servers = scalar keys %{$dbeol->{$customer}{DB_LIST}{$type}} || "0";
      			if ($dbeol->{$customer}{ORACLE}{$type}) {
     	 				$total_oracle_servers = scalar keys %{$dbeol->{$customer}{ORACLE}{$type}};
     				}
     				if ($dbeol->{$customer}{ORACLE_INSTANCE}{$type}) {
         			$total_oracle_instances = scalar @{$dbeol->{$customer}{ORACLE_INSTANCE}{$type}};
      			}

      			if ($dbeol->{$customer}{MSSQL}{$type}) {
     	 				$total_mssql_servers = scalar keys %{$dbeol->{$customer}{MSSQL}{$type}};
     				}
      			if ($dbeol->{$customer}{MSSQL_INSTANCE}{$type}) {
         			$total_mssql_instances = scalar @{$dbeol->{$customer}{MSSQL_INSTANCE}{$type}};
      			}

      			if ($dbeol->{$customer}{OTHER}{$type}) {
     	 				$total_other_servers = scalar keys %{$dbeol->{$customer}{OTHER}{$type}};
     				}
      			if ($dbeol->{$customer}{OTHER_INSTANCE}{$type}) {
         			$total_other_instances = scalar @{$dbeol->{$customer}{OTHER_INSTANCE}{$type}};
      			}

		   } elsif (defined($afg_db->{$customer}{DBTYPE})) {
		     if ($type !~ /non/) {
		      foreach my $db_type (keys %{$afg_db->{$customer}{DBTYPE}}) {
		      	$db_managed_instances = $afg_db->{$customer}{DBTYPE}{$db_type}{total_instances};
		      	$db_managed_servers = $afg_db->{$customer}{DBTYPE}{$db_type}{total_db_servers};
		      	$total_oracle_instances = $afg_db->{$customer}{DBTYPE}{oracle}{total_instances} || "0";
		      	$total_oracle_servers = 0;
		      	$total_mssql_servers = 0;
		      	$total_mssql_instances = $afg_db->{$customer}{DBTYPE}{'sql server'}{total_instances} || "0";
		      	$total_other_instances = ($afg_db->{$customer}{DBTYPE}{ims}{total_instances} + $afg_db->{$customer}{DBTYPE}{'db2 luw'}{total_instances} + $afg_db->{$customer}{DBTYPE}{ims}{total_instances}
      	                   + $afg_db->{$customer}{DBTYPE}{progress}{total_instances} + $afg_db->{$customer}{DBTYPE}{sybase}{total_instances} + $afg_db->{$customer}{DBTYPE}{mysql}{total_instances}) || "0";
		      	$total_other_servers = 0;
		      }
		     }
		   }

		   if ($type !~ /non/i) {
		   	if (defined($dbeol->{$customer}{ORACLE_INSTANCE}{not_in_scope})) 	{	 $not_in_scope += scalar @{$dbeol->{$customer}{ORACLE_INSTANCE}{not_in_scope}}; }
		   	if (defined($dbeol->{$customer}{MSSQL_INSTANCE}{not_in_scope})) 	{	 $not_in_scope += scalar @{$dbeol->{$customer}{MSSQL_INSTANCE}{not_in_scope}}; }
		   	if (defined($dbeol->{$customer}{OTHER_INSTANCE}{not_in_scope})) 	{	 $not_in_scope += scalar @{$dbeol->{$customer}{OTHER_INSTANCE}{not_in_scope}}; }
				}
	$db_managed_instances = $total_oracle_instances + $total_mssql_instances +  $total_other_instances;
	my %x = (total_db_instances => $db_managed_instances, total_db_servers=>$db_managed_servers,
            total_oracle_instances=>$total_oracle_instances, total_mssql_instances => $total_mssql_instances, total_other_instances => $total_other_instances,
            total_oracle_servers=>$total_oracle_servers, total_mssql_servers => $total_mssql_servers, total_other_servers => $total_other_servers,
            total_exempted => $not_in_scope);

   return (\%x);

}


sub get_storage_baseline {
  	my ($customer,$capability,$storage_baseline,$storage_sp) = @_;

   my ($baseline_storage_array_prd,$baseline_storage_array_nonprd,$baseline_storage_switch_prd,$baseline_storage_switch_nonprd);
   my ($baseline_storage_other_prd,$baseline_storage_other_nonprd,$exception_prd,$exception_nonprd);



   $baseline_storage_array_prd = scalar keys %{$storage_baseline->{$customer}{prd}{supported}{array}};
	 $baseline_storage_array_nonprd = scalar keys %{$storage_baseline->{$customer}{nonprd}{supported}{array}};
	 $baseline_storage_switch_prd = scalar keys %{$storage_baseline->{$customer}{prd}{supported}{switch}};
	 $baseline_storage_switch_nonprd = scalar keys %{$storage_baseline->{$customer}{nonprd}{supported}{switch}};
	 $baseline_storage_other_prd = scalar keys %{$storage_baseline->{$customer}{prd}{supported}{other}};
	 $baseline_storage_other_nonprd = scalar keys %{$storage_baseline->{$customer}{nonprd}{supported}{other}};

	 #AFG
	 if (defined($storage_sp->{$customer}{ARRAYS}{COUNT})) {
  	 			$baseline_storage_array_prd += $storage_sp->{$customer}{ARRAYS}{COUNT};
  	 }

  if (defined($storage_sp->{$customer}{SWITCH}{COUNT})) {
  	 			$baseline_storage_switch_prd += $storage_sp->{$customer}{SWITCH}{COUNT};
  }

	 my $total_storage_ci_prd = $baseline_storage_array_prd + $baseline_storage_switch_prd + $baseline_storage_other_prd;
   my $total_storage_ci_nonprd = $baseline_storage_array_nonprd + $baseline_storage_switch_nonprd + $baseline_storage_other_nonprd;
   $exception_prd = scalar keys %{$storage_baseline->{$customer}{prd}{not_in_scope}{array}};
   $exception_prd += scalar keys %{$storage_baseline->{$customer}{prd}{not_in_scope}{switch}};
   $exception_prd += scalar keys %{$storage_baseline->{$customer}{prd}{not_in_scope}{other}};

   $exception_nonprd = scalar keys %{$storage_baseline->{$customer}{nonprd}{not_in_scope}{array}};
   $exception_nonprd += scalar keys %{$storage_baseline->{$customer}{nonprd}{not_in_scope}{switch}};
   $exception_nonprd += scalar keys %{$storage_baseline->{$customer}{nonprd}{not_in_scope}{other}};

   my %x = (array_prd => $baseline_storage_array_prd, array_nonprd => $baseline_storage_array_nonprd,
  					 switch_prd => $baseline_storage_switch_prd, switch_nonprd => $baseline_storage_switch_nonprd,
  					 other_prd => $baseline_storage_other_prd, other_nonprd => $baseline_storage_other_nonprd,
  					 total_prd => $total_storage_ci_prd, total_nonprd => $total_storage_ci_nonprd,
  					 exception_prd => $exception_prd,exception_nonprd => $exception_nonprd);
  	return (\%x);
}


sub get_tracker_details
{
	my ($internal_tracker,$customer, $cap, $tile) = @_;

	#Internal Tracker
	my ($t_str, $t_rev);
	my ($tracker_review, $tracker_review_color, $tracker);

	if (defined($internal_tracker->{$customer}{$cap}{$tile})) {

		foreach my $id (keys %{$internal_tracker->{$customer}{$cap}{$tile}}) {

			$t_str = "<a href=\"$internal_tracker->{$customer}{$cap}{$tile}{$id}{sp_link}\">$internal_tracker->{$customer}{$cap}{$tile}{$id}{status}</a>";
			$t_rev = $internal_tracker->{$customer}{$cap}{$tile}{$id}{days_til_review};
			last;
		}

		$tracker = $t_str;

		if ($t_rev > 0) {
			$tracker_review = $t_rev;
			$tracker_review_color = $green;
		} else {
			$tracker_review = "$t_rev days overdue";
			$tracker_review_color = $red;
		}
	}

	return($tracker_review, $tracker_review_color, $tracker);
}


sub callT1
{
	my ($protocol, $t1_server, $port, $user, $pass, $method, $arg_str)= @_;
	my ($fh,$fn);
   my $success=0;
   my $message;
   my $data="";

   my $url = sprintf "%s://%s:%s/OvCgi/GTOD_CC/webservice/%s",$protocol, $t1_server, $port, $method;

   # Add arguments if needed
   if ($arg_str ne "") {	$url .= "?$arg_str"; }

	print "URL = $url\n";

	my $ua = LWP::UserAgent->new;
	$ua->timeout(180);

	$ua->credentials("$t1_server:$port", "Authentication required", $user, $pass);
	$ua->default_header('Accept-Encoding' => 'gzip');

	my $req = HTTP::Request->new(GET => $url);
	my $resp = $ua->request($req);

	if ($resp->is_success) {
	   $message = $resp->decoded_content;
	   $success=1;
	}
	else {
	   $success=0;
	}
	#print "$message";
	if ($success and $message ne "") {

		eval {
			my $json_data = encode_utf8( $message );
		  $data = JSON->new->utf8->decode($json_data);
		};
		if ($@) { print "ERROR $@\n"; }
	}

	return ($success,$data);
}

sub callT1_text
{
   my ($protocol, $t1_server, $port, $user, $pass, $method, $arg_str)= @_;
	my ($fh,$fn);
	my $success=0;
   my $message;
   my $data="";

   my $url = sprintf "%s://%s:%s/OvCgi/GTOD_CC/webservice/%s",$protocol, $t1_server, $port, $method;

   # Add arguments if needed
   if ($arg_str ne "") {	$url .= "?$arg_str"; }

	print "URL = $url\n";

	my $ua = LWP::UserAgent->new;
	$ua->timeout(180);

	$ua->credentials("$t1_server:$port", "Authentication required", $user, $pass);

	my $req = HTTP::Request->new(GET => $url);
	my $resp = $ua->request($req);

	if ($resp->is_success) {
	   $message = $resp->decoded_content;
	   $success=1;
	}
	else {
	   $success=0;
	}

	return ($success,$message);
}


sub callT1_JSON
{
	my ($protocol, $t1_server, $port, $user, $pass, $method, $post_data)= @_;

	my ($fh,$fn);
	my $success=0;
  my $message;
  my $data="";

  my $url = sprintf "%s://%s:%s/OvCgi/GTOD_CC/webservice/%s",$protocol, $t1_server, $port, $method;

	#print "URL = $url\n";
	my $ua = LWP::UserAgent->new;
	$ua->timeout(180);

	$ua->credentials("$t1_server:$port", "Authentication required", $user, $pass);

	my $req = HTTP::Request->new(POST => $url);

	$req->content_type("application/json");
	$req->content($post_data);

	my $resp = $ua->request($req);
	if ($resp->is_success) {
 	   $data = $resp->decoded_content;
 	   $success = 1;
	}

	return ($success,$data);
}

sub read_config()
{
	return \%_cfg;
}

sub _read_config
{
	my $filename = "$cfg_dir/oc_master.cfg";

	open(IN, $filename);

	while(<IN>) {
		chomp;
    next if (/^\s*#/);

    #Truncate any comments on ends of config lines
    s/^(.*?)\s+\#//;


## MOdded swiched parenthis to RHS as broke java properties syntax rules
#		if (/^Probe_Locations\((.*?)\)\s*\=\s*(.*?)$/) {
		if (/^Probe_Locations\s*\=\s*\((.*?)\)(.*?)$/) {
			push @{$_cfg{PROBE_LOCATIONS}{lc($1)}}, lc($2);
		} elsif (/^\s*DATACOLLECTION_RAWCACHE_SYNC_LIST\s*\=\s*(.*?)\s*$/) {
			push @{$_cfg{DATACOLLECTION_RAWCACHE_SYNC_LIST}}, split(/::/,$1);
		} elsif (/^\s*DATACOLLECTION_CACHE_SYNC_LIST\s*\=\s*(.*?)\s*$/) {
			push @{$_cfg{DATACOLLECTION_CACHE_SYNC_LIST}}, split(/::/,$1);
		} else {
    	# GLOBALS
    	if (/^\s*(.*?)\s*\=\s*(.*?)\s*$/) { $_cfg{$1} = $2; }
		}
	}
	close(IN);

	if ($_cfg{USE_BASE64}) {
		$ENV{OC_AUTH_FN}=decode($ENV{$_cfg{OC_AUTH_FN}});
		$ENV{OC_AUTH_NUM}=decode($ENV{$_cfg{OC_AUTH_NUM}});
		$ENV{OC_AUTH_MAIL}=decode($ENV{$_cfg{OC_AUTH_MAIL}});
		$ENV{OC_AUTH_UID}=decode($ENV{$_cfg{OC_AUTH_UID}});
		$ENV{OC_AUTH_GPUID}=decode($ENV{$_cfg{OC_AUTH_GPUID}});
		$ENV{OC_AUTH_SN}=decode($ENV{$_cfg{OC_AUTH_SN}});
	} else {
		$ENV{OC_AUTH_FN}=$ENV{$_cfg{OC_AUTH_FN}};
		$ENV{OC_AUTH_NUM}=$ENV{$_cfg{OC_AUTH_NUM}};
		$ENV{OC_AUTH_MAIL}=$ENV{$_cfg{OC_AUTH_MAIL}};
		$ENV{OC_AUTH_UID}=$ENV{$_cfg{OC_AUTH_UID}};
		$ENV{OC_AUTH_GPUID}=$ENV{$_cfg{OC_AUTH_GPUID}};
		$ENV{OC_AUTH_SN}=$ENV{$_cfg{OC_AUTH_SN}};
	}

	if (!defined($ENV{OC_AUTH_UID})) {
		if(defined($ENV{HTTP_PROXY_USER})) {
			$ENV{OC_AUTH_UID} = $ENV{HTTP_PROXY_USER};
			$ENV{OC_AUTH_FN}=$ENV{HTTP_PROXY_FN};
			$ENV{OC_AUTH_NUM}=$ENV{MELLON_employeeNumber};
			$ENV{OC_AUTH_MAIL}=$ENV{MELLON_mail};
			$ENV{OC_AUTH_UID}=$ENV{HTTP_PROXY_USER};
			$ENV{OC_AUTH_GPUID}=$ENV{HTTP_PROXY_USER};
			$ENV{OC_AUTH_SN}=$ENV{HTTP_PROXY_SN};
		}
	}
}

sub decode
{
	my ($str) = @_;
	my $decoded = '';
	if ($str =~ /^\?UTF-8\?B\?(.*)$/i) {
		$decoded = decode_base64($1);
	}
	return $decoded;
}

sub read_user_access_config
{
	use YAML::XS 'LoadFile';
	my $ua_cfg = LoadFile("$cfg_dir/oc_user_access.yaml");
	return $ua_cfg;
#
#
#	my $filename = "$cfg_dir/oc_user_access.cfg";
#	my %ua_cfg;
#
#	open(IN, $filename);
#
#	while(<IN>) {
#		chomp;
#      next if (/^\s*#/);
#
#      #Truncate any comments on ends of config lines
#      s/^(.*?)\s+\#//;
#
#    	if (/^ALL\=(.*?)\s*$/) {
#    	   $ua_cfg{$1}{ALL} = '1';
#    	}
#
#    	if (/^CUSTOMER\((.*?)\)\=(.*?)\s*$/) {
#    	   $ua_cfg{$2}{$1} = '1';
#    	}
#
#	}
#	close(IN);
#
#	return \%ua_cfg;
}


###############################################################################
# lists_getcollection
#
# inputs
#     $schema_ua_sp - UserAgent Object
#
#
# returns
#     none
#
# Algorithm
# Use WebService to invoke GetListCollection method
# Displayes available lists as a print statement
###############################################################################
sub lists_getcollection
{
    my ($schema, $endpoint) = @_;

    my (%id_by_listname);

    my $message =
      '<?xml version="1.0" encoding="utf-8"?>
       <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
       <soap:Body>
         <GetListCollection xmlns="http://schemas.microsoft.com/sharepoint/soap/" />
       </soap:Body>
       </soap:Envelope>';

      my $request = HTTP::Request->new(POST => $endpoint);
      $request->header(SOAPAction => 'http://schemas.microsoft.com/sharepoint/soap/GetListCollection');
      $request->content($message);
      $request->content_type("text/xml; charset=utf-8");

      #print Dumper ($request);
      my $response = $schema->request($request);

      if ($response->is_success and $response->as_string !~/ErrorText/i) {
         print "Successfully Read Sharepoint (getListCollection)...\n";

         my $row_count = 0;
         my ($title);
         foreach my $r (split(/\<List DocTemplate/, $response->as_string)) {
            $row_count++;
            if ($r =~ /Title\=\"(.*?)\"/i) {
               $title = $1;
            }
            if ($r =~ /Name\=\"(.*?)\"/i) {
               $id_by_listname{$title} = $1;
               #print "Title ($title) ID ($1)\n";
            }

         }

      } elsif ($response->is_success and $response->as_string =~ /ErrorText/i) {
         my ($err);
         ($err = $response->as_string)=~s/^.*?\<ErrorText\>(.*?)\<\/ErrorText\>.*/$1/g;
         print "Failed to read Sharepoint....ERROR $err\n";


      } else {
         die "Failed to read Sharepoint.. Error: ". $response->as_string;

      }


      return \%id_by_listname;



}


###############################################################################
# lists_getitems
#
# inputs
#     $list_name - Name of sharepoint list to scrape data from
#     $view_name - Name of the sharepoint view.  This can be blank (default)
#                  or {GUID}.  Use Sharepoint sync with excel to find GUID
#     $schema - UserAgent reference
#
# returns
#     \@data - reference to array of hashes (array is rows in Sharepoint,
#              hash is a columns/values
#
# Algorithm
#  Populate webservice soap envelope - and post
#  Parse result into @data
#  This could have been done with xml parser module - but this works fine
###############################################################################
sub lists_getitems
{
    my ($list_name, $view_name, $schema, $endpoint) = @_;

    my (@data);

    my $message =
      '<?xml version="1.0" encoding="utf-8"?>
       <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
       <soap:Body>
         <GetListItems xmlns="http://schemas.microsoft.com/sharepoint/soap/">
            <listName>'.$list_name.'</listName>
            <viewName>'.$view_name.'</viewName>
            <rowLimit>99999</rowLimit>
         </GetListItems>
      </soap:Body>
      </soap:Envelope>';

      my $request = HTTP::Request->new(POST => $endpoint);
      $request->header(SOAPAction => 'http://schemas.microsoft.com/sharepoint/soap/GetListItems');
      $request->content($message);
      $request->content_type("text/xml; charset=utf-8");

      $schema->timeout(600);

      print "About to scrape sharepoint list : $list_name\n";

      my $response = $schema->request($request);

			if ($response->as_string =~ /read timeout/i) {

				print "Timeout reading sharepoint $list_name\n";
			} elsif ($response->is_success and $response->as_string !~/ErrorText/i) {
         print "Successfully Read Sharepoint ($list_name)...\n";
         #   <z:row ows_Attachments='0' ows_LinkTitle='E494' ows_MetaInfo='8;#' ows__ModerationStatus='0' ows__Level='1' ows_Title='E494' ows_ID='8' ows_UniqueId='8;#{19BB42D9-0FFA-4324-847F-5CAF10B7A7F5}' ows_owshiddenversion='1' ows_FSObjType='8;#0' ows_Created_x0020_Date='8;#2015-02-17 23:41:53' ows_Created='2015-02-17 23:41:53' ows_FileLeafRef='8;#8_.000' ows_PermMask='0x1b03c4312ef' ows_Modified='2015-02-17 23:41:53' ows_FileRef='8;#teams/ProductionOperationsSP/Lists/People  MRUs/8_.000' />

         my $row_count = 0;
         foreach my $r (split(/\<z\:row/, $response->as_string)) {
            $row_count++;
            next if ($row_count == 1);
            my %x;
            foreach my $field (split(/ows_/, $r)) {
               if ($field =~/(.*?)\=\'(.*?)\'/) {
                  $x{"ows_$1"} = lc($2);
                  $x{"ows_$1"} =~ s/\&amp;/\&/g;
                  $x{"ows_$1"} =~ s/\&#39;/\'/g;
                  $x{"ows_$1"} =~ s/\&#34;/\"/g;
                  $x{"ows_$1"} =~ s/\&#60;/\</g;
                  $x{"ows_$1"} =~ s/\&#62;/\>/g;
               }
            }
            push @data, \%x if (scalar(%x) > 0);

         }

      } elsif ($response->is_success and $response->as_string =~ /ErrorText/i) {
         my ($err);
         ($err = $response->as_string)=~s/^.*?\<ErrorText\>(.*?)\<\/ErrorText\>.*/$1/g;
         print "Failed to read Sharepoint $list_name  ....ERROR $err\n";

      } else {
         print "Failed to read Sharepoint $list_name .. Error: \n";
         print $response->as_string;
         #exit;
      }

      return @data;

}


sub map_customer_to_legacy_sp
{
	my ($account_reg, $customer) = @_;

	if (defined($account_reg->{$customer}{sp_company})) {
	      # from Sharepoint to DeliveryMap
	      return $account_reg->{$customer}{sp_company} ;
	 } else {
	 	return "NOT_MAPPED";
	 }
}


sub map_dm_customer_to_esl
{
	my ($account_reg, $customer) = @_;

	my $c;
	my $found = 0;

	if ($account_reg->{lc($customer)}{sp_esl_company} ne "") {
		return $account_reg->{lc($customer)}{sp_esl_company};
	} else {
		return "NOT_MAPPED";
	}

}


sub map_capabilities
{
	my ($capability, $sub_capability) = @_;

	if ($capability =~ /enterprise application operations/i) {
		return "enterprise_application_operations";
	} elsif ($capability =~ /enterprise service management/i) {
		return "enterprise_service_management";
	} elsif ($capability =~ /mainframe/i) {
		return "mainframe";
	} elsif ($capability =~ /monitoring/i) {
		return "monitoring";
	} elsif ($capability =~ /network/i) {
		return "network";
	} elsif ($capability =~ /security/i) {
		return "security";
	} elsif ($capability =~ /software services/i) {
		if ($sub_capability =~ /database|oracle|msql/i) {
			return "database";
		} else {
			return "software_services";
		}
	} elsif ($capability =~ /storage/i) {
		if ($sub_capability =~ /backup|archive/i) {
			return "backup";
		} else {
			return "storage";
		}
	} elsif ($capability =~ /unix/i) {
		return "unix_linux";
	} elsif ($capability =~ /wintel/i) {
		return "windows";
	} elsif ($capability =~ /global service desk/i) {
		return "iServe";
	} elsif ($capability =~ /workplace services/i) {
		if ($sub_capability =~ /messaging/i) {
			return "messaging";
		} else {
			return "workplace_services";
		}
	} else {
		return "not_mapped";
	}
}

sub map_hpsa_mesh
{
	my ($mesh) = @_;

	if ($mesh =~ /abbvie egv|abbvie-egv|abbvie egv/i) {
		return "hp-sa abbvie egv";
	} elsif ($mesh =~ /alu/i) {
		return "hp-sa alu";
	} elsif ($mesh =~ /alu preprod|alu_pre|alp/i) {
		return "hp-sa alu preprod";
	} elsif ($mesh =~ /apj|ap/i) {
		return "hp-sa apj";
	} elsif ($mesh =~ /basf|bas/i) {
		return "hp-sa basf";
	} elsif ($mesh =~ /cibc/i) {
		return "hp-sa cibc";
	} elsif ($mesh =~ /canada|can/i) {
		return "hp-sa canada";
	} elsif ($mesh =~ /ccel prod|ccel_prod|cel/i) {
		return "hp-sa ccell prod";
	} elsif ($mesh =~ /eon_black|e.on black|ebl/i) {
		return "hp-sa e.on black";
	} elsif ($mesh =~ /emea central|emea_central|emea-central|emc/i) {
		return "hp-sa emea central";
	} elsif ($mesh =~ /emea sdn|emea_sdn|emea-sdn|sdn/i) {
		return "hp-sa emea sdn";
	} elsif ($mesh =~ /emea south|emea_south|emea-south|emc/i) {
		return "hp-sa emea south";
	} elsif ($mesh =~ /emea ta1|emea_ta1|emea-ta1|em1/i) {
		return "hp-sa emea ta1";
	} elsif ($mesh =~ /emea ta2|emea_ta2|emea-ta2|em2/i) {
		return "hp-sa emea ta2";
	} elsif ($mesh =~ /emea ta3|emea_ta3|emea-ta3|em3/i) {
		return "hp-sa emea ta3";
	} elsif ($mesh =~ /fpc|finland pc/i) {
		return "hp-sa finland pc";
	} elsif ($mesh =~ /lac|la/i) {
		return "hp-sa lac";
	} elsif ($mesh =~ /pci/i) {
		return "hp-sa pci";
	} elsif ($mesh =~ /us1|amer|us 1/i) {
		return "hp-sa us1";
	} elsif ($mesh =~ /us2|us-ta2|us 2/i) {
		return "hp-sa us2";
	} else {
		return "not_mapped";
	}
}

sub filter_names
{
	my ($name) = @_;

	 $name =~ s/[^[:ascii:]]//g;
   $name =~ s/([^\s!\#\$&%\'-;=?-~<>])//g;
   $name =~ s/\(//g;
   $name =~ s/\)//g;

   return $name;
}


# Listen up Peoples - SP here NOW MEANS DeliveryMap....
# If you think the function name choice is not so good
# Your correct - and maybe you can volunteer to go back and
# change all calling utilities.... ;)
sub map_customer_to_sp
{
   my ($account_reg, $customer, $sub_business, $type, $department) = @_;
   my $sp_customer_name;
   #Default
   my ($mapped_customer) = "NOT_MAPPED";
   $customer=lc($customer);

	 $customer = filter_names($customer);

  # print "--$customer\n";
 	foreach $sp_customer_name (sort keys %{$account_reg}) {
 		my $c = filter_names($account_reg->{$sp_customer_name}{sp_esl_company});

   	if ( ($type eq "ESL") and ($c eq $customer) ) {
	  	# from ESL to Sharepoint
	  	my $sp_sub_bus = $account_reg->{$sp_customer_name}{sp_sub_business} || "all";
	    if ($sub_business ne "") {
	    	#print "checking $account_reg->{$sp_customer_name}{sp_sub_business} against $sub_business\n";
	      if ($sp_sub_bus eq $sub_business) {
	      	$mapped_customer = $sp_customer_name;
	      	return ($mapped_customer);
	      }
	      if ($sp_sub_bus =~ /all/i || $sp_sub_bus eq "") {
	      	#Take note of match but keep checking incase there is another match on sub business
	      	$mapped_customer = $sp_customer_name;
	      }
			} else {
	      if ($sp_sub_bus eq "all" || $sp_sub_bus eq ""){
	      	$mapped_customer = $sp_customer_name;
	      	return ($mapped_customer);
	      }
			}
		}



		if ( ($type eq "SP") and ($account_reg->{$sp_customer_name}{sp_company} eq $customer) ) {
			# from PPMC to Sharepoint
	   	$mapped_customer = $sp_customer_name;
	    return ($mapped_customer) if ($mapped_customer !~ /NOT_MAPPED/i);
		}

	  if ( ($type eq "PPMC") and ($account_reg->{$sp_customer_name}{sp_ppmc_company} eq $customer) ) {
	   	# from PPMC to Sharepoint
	  	$mapped_customer = $sp_customer_name;
	    return ($mapped_customer) if ($mapped_customer !~ /NOT_MAPPED/i);
	  }

	  if ( ($type eq "ALDEA") and ($account_reg->{$sp_customer_name}{sp_aldea_company} eq $customer) ) {
	  	# from Aldea to Sharepoint
	   	$mapped_customer = $sp_customer_name;
	    return ($mapped_customer) if ($mapped_customer !~ /NOT_MAPPED/i);
		}

	  if ( ($type eq "RTOP") and ($account_reg->{$sp_customer_name}{sp_rtop_company} =~ /\Q$customer\E/i) ) {
	  	# from RTOP to Sharepoint
	    $mapped_customer = $sp_customer_name;
	    return ($mapped_customer) if ($mapped_customer !~ /NOT_MAPPED/i);
	  }

	  if ( ($type eq "HPSE") and ($account_reg->{$sp_customer_name}{sp_hpse_company} eq $customer) ) {
	  	# from RTOP to Sharepoint
			$mapped_customer = $sp_customer_name;
	    return ($mapped_customer) if ($mapped_customer !~ /NOT_MAPPED/i);
		}

	  if ( ($type eq "MWS") and ($account_reg->{$sp_customer_name}{sp_mws_company} eq $customer) ) {
	  	# from RTOP to Sharepoint
	    $mapped_customer = $sp_customer_name;
	    return ($mapped_customer) if ($mapped_customer !~ /NOT_MAPPED/i);
		}

	  if ( ($type eq "DOMS") and ($account_reg->{$sp_customer_name}{sp_doms_company} eq $customer) ) {
	  	# from DOMS to Sharepoint
	    $mapped_customer = $sp_customer_name;
	    return ($mapped_customer) if ($mapped_customer !~ /NOT_MAPPED/i);
	  }
	  if ( ($type eq "NGDM") and ($account_reg->{$sp_customer_name}{sp_ngdm_company} eq $customer) ) {
	  	# from DOMS to Sharepoint
	    $mapped_customer = $sp_customer_name;
	    return ($mapped_customer) if ($mapped_customer !~ /NOT_MAPPED/i);
	  }
	  if ( ($type eq "SOD") and ($account_reg->{$sp_customer_name}{sp_sod_company} eq $customer) ) {
	  	# from STart of DAy to Sharepoint
	    $mapped_customer = $sp_customer_name;
	    return ($mapped_customer) if ($mapped_customer !~ /NOT_MAPPED/i);
		}
	  if ( ($type eq "SMKPI") and ($account_reg->{$sp_customer_name}{sp_smkpi_company} eq $customer) ) {
	  	# from STart of DAy to Sharepoint
	    $mapped_customer = $sp_customer_name;
	    return ($mapped_customer) if ($mapped_customer !~ /NOT_MAPPED/i);
		}
		###AWS###
		if ( ($type eq "AWS") and ($account_reg->{$sp_customer_name}{sp_aws_company} eq $customer) ) {
	    $mapped_customer = $sp_customer_name;
	    return ($mapped_customer) if ($mapped_customer !~ /NOT_MAPPED/i);
		}

		###T3###
		if ( ($type eq "T3") and ($account_reg->{$sp_customer_name}{sp_t3_company} eq $customer) ) {
	    $mapped_customer = $sp_customer_name;
	    return ($mapped_customer) if ($mapped_customer !~ /NOT_MAPPED/i);
		}

		###MAGMA###
		if ( ($type eq "MAGMA") and ($account_reg->{$sp_customer_name}{sp_magma_company} eq $customer) ) {
	    $mapped_customer = $sp_customer_name;
	    return ($mapped_customer) if ($mapped_customer !~ /NOT_MAPPED/i);
		}

		###DMAR###
		if ( ($type eq "DMAR") and ($account_reg->{$sp_customer_name}{dmar_id} eq $customer) ) {
	    $mapped_customer = $sp_customer_name;
	    return ($mapped_customer) if ($mapped_customer !~ /NOT_MAPPED/i);
		}

		if ( ($type eq "DMAR") and ($account_reg->{$sp_customer_name}{dmar_company} eq $customer) ) {
	    $mapped_customer = $sp_customer_name;
	    return ($mapped_customer) if ($mapped_customer !~ /NOT_MAPPED/i);
		}



	  ##CMDBPLUS
	  if ( ($type eq "CMDBPLUS") and ($account_reg->{$sp_customer_name}{sp_cmdbplus_company} eq $customer) ) {
	  	$mapped_customer = $sp_customer_name;
	    if ($mapped_customer !~ /NOT_MAPPED/i) {
	     	return ($mapped_customer);
	    } else {
	    	foreach my $alias_type (keys %{$account_reg->{$sp_customer_name}{esl_company_alias}}) {
	      	foreach my $value (@{$account_reg->{$sp_customer_name}{esl_company_alias}{$alias_type}}) {
						if ($value eq $customer) {
							$mapped_customer = $sp_customer_name;
							return ($mapped_customer) if ($mapped_customer !~ /NOT_MAPPED/i);
						}
					}
				}
			}
		}
	  #Best Guess

		if ($type eq "ANY") {

			foreach my $alias_type (keys %{$account_reg->{$sp_customer_name}{esl_company_alias}}) {
				foreach my $value (@{$account_reg->{$sp_customer_name}{esl_company_alias}{$alias_type}}) {
					if ($value eq $customer) {
						$mapped_customer = $sp_customer_name;
						return ($mapped_customer) if ($mapped_customer !~ /NOT_MAPPED/i);
					}
				}
			}

		 	if	($account_reg->{$sp_customer_name}{sp_sdx_company} eq $customer) {
	     	# from SDX to Sharepoint
	   		$mapped_customer = $sp_customer_name;
	     	return ($mapped_customer) if ($mapped_customer !~ /NOT_MAPPED/i);
	   	}
		 	if	($account_reg->{$sp_customer_name}{sp_ppmc_company} eq $customer) {
	     	# from PPMC to Sharepoint
	   		$mapped_customer = $sp_customer_name;
	     	return ($mapped_customer) if ($mapped_customer !~ /NOT_MAPPED/i);
	   	}

	   	if ($account_reg->{$sp_customer_name}{sp_sod_company} eq $customer) {
	    	# from STart of DAy to Sharepoint
	    	$mapped_customer = $sp_customer_name;
	      return ($mapped_customer) if ($mapped_customer !~ /NOT_MAPPED/i);
	   	}
	   	if ($account_reg->{$sp_customer_name}{sp_smkpi_company} eq $customer ) {
	    	# from SMKPI to Sharepoint
	      $mapped_customer = $sp_customer_name;
	      return ($mapped_customer) if ($mapped_customer !~ /NOT_MAPPED/i);
	   	}
		 	#print "---$customer\n";
		 	if ($account_reg->{$sp_customer_name}{sp_rtop_company} =~ /^$customer$/i)  {
	     	# from RTOP to Sharepoint
	     	$mapped_customer = $sp_customer_name;
	     	return ($mapped_customer) if ($mapped_customer !~ /NOT_MAPPED/i);
	   	}

		 	if ($account_reg->{$sp_customer_name}{sp_doms_company} =~ /^$customer$/i)  {
	     	# from DOMS to Sharepoint
	     	$mapped_customer = $sp_customer_name;
	     	return ($mapped_customer) if ($mapped_customer !~ /NOT_MAPPED/i);
	   	}

	   	if ($account_reg->{$sp_customer_name}{sp_company} =~ /^$customer$/i)  {
	     	# from RTOP to Sharepoint
	     	$mapped_customer = $sp_customer_name;
	     	return ($mapped_customer) if ($mapped_customer !~ /NOT_MAPPED/i);
	   	}
	   	if ($account_reg->{$sp_customer_name}{sp_esl_company} eq $customer) {
	   		#	print "HERE $sp_customer_name\n";
	    	# from ESL to Sharepoint
	      if ($sub_business ne "") {
	      	if ($account_reg->{$sp_customer_name}{sp_sub_business} =~ /all/i)  {
	      		$mapped_customer = $sp_customer_name;
	      	#}	elsif ($account_reg->{$sp_customer_name}{sp_sub_business}=~ /$sub_business/i) {
	      	}	elsif ($account_reg->{$sp_customer_name}{sp_sub_business} eq $sub_business) {
	      		$mapped_customer = $sp_customer_name;
	      	}
	      	#
	      	return ($mapped_customer) if ($mapped_customer !~ /NOT_MAPPED/i);
	    	} else {
	      	$mapped_customer = $sp_customer_name;
	      }
	  	}

	  	###AWS###
			if ( $account_reg->{$sp_customer_name}{sp_aws_company} eq $customer) {
		    $mapped_customer = $sp_customer_name;
	    	return ($mapped_customer) if ($mapped_customer !~ /NOT_MAPPED/i);
			}

			###T3###
			if ( $account_reg->{$sp_customer_name}{sp_t3_company} eq $customer)  {
	  	  $mapped_customer = $sp_customer_name;
		    return ($mapped_customer) if ($mapped_customer !~ /NOT_MAPPED/i);
			}

			###MAGMA###
			if ( $account_reg->{$sp_customer_name}{sp_magma_company} eq $customer)  {
	  	  $mapped_customer = $sp_customer_name;
		    return ($mapped_customer) if ($mapped_customer !~ /NOT_MAPPED/i);
			}

			###DMAR###
			if ( $account_reg->{$sp_customer_name}{dmar_id} eq $customer) {
	    	$mapped_customer = $sp_customer_name;
	    	return ($mapped_customer) if ($mapped_customer !~ /NOT_MAPPED/i);
			}

			if ( $account_reg->{$sp_customer_name}{dmar_company} eq $customer) {
	    	$mapped_customer = $sp_customer_name;
	    	return ($mapped_customer) if ($mapped_customer !~ /NOT_MAPPED/i);
			}

	    if ($sp_customer_name =~ /^$customer$/i) {
	    	$mapped_customer = $sp_customer_name;
	    	return ($mapped_customer) if ($mapped_customer !~ /NOT_MAPPED/i);
	    }
	 	}
	}
	return($mapped_customer);
}

sub map_inc_customer{
	my ($account_reg, $esl_business, $ovsc_customer, $ovsc_department) = @_;

	$esl_business = filter_names($esl_business);

	#print "Mapping $esl_business:$ovsc_customer:$ovsc_department\n";
	foreach my $sp_customer (keys %{$account_reg}) {

		my ($found_code, $found_dept, $found_business);

		if (uc($ovsc_customer) eq "ECS" or uc($ovsc_customer) eq "UTILITY-SERVICES" or uc($ovsc_customer) eq "NZFS" or uc($ovsc_customer) eq "NZCS" or uc($ovsc_customer) eq "HP") {
			# Match departments inscope only
  		foreach my $dept (@{$account_reg->{$sp_customer}{esl_company_alias}{'ovsc department name'}}) {
  			$found_dept = 1 if (lc($dept) eq lc($ovsc_department));
  		}

  		foreach my $code (@{$account_reg->{$sp_customer}{esl_company_alias}{'ovsc company code'}}) {
  			$found_code = 1 if (lc($code) eq lc($ovsc_customer));
  			#print "Found Code\n";
  		}

  		if ($found_code and $found_dept) {
#  			print "Mapping $esl_business:$ovsc_customer:$ovsc_department to Delivery Map customer $sp_customer\n";
  			return $sp_customer;
  		}
		} elsif (uc($esl_business) eq "ENTERPRISE CLOUD SERVICES") {
			# We can't just map on OVSC Company Vode and Department or will map to the ECS ESL Business!
			# There is a risk that this will match to ECS anyway as both the customer sub business and ECS sub business are set up with he same OVSC Company Code and Department!
			foreach my $code (@{$account_reg->{$sp_customer}{esl_company_alias}{'ovsc company code'}}) {
  			return $sp_customer if (lc($code) eq lc($ovsc_customer));
  		}
		} else {
			# Match on ESL Business name only
			if (lc($esl_business) eq lc($account_reg->{$sp_customer}{sp_esl_company})) {
  			$found_business = 1;
  			return $sp_customer;
  			#print "Found Business\n";
  		} elsif (lc($esl_business) eq lc($account_reg->{$sp_customer}{sp_aws_company})) {
	  			$found_business = 1;
	  			return $sp_customer;
	  			#print "Found Business\n";
  		} elsif (lc($esl_business) eq lc($account_reg->{$sp_customer}{sp_t3_company})) {
	  			$found_business = 1;
	  			return $sp_customer;
	  			#print "Found Business\n";
  		} elsif (lc($esl_business) eq lc($account_reg->{$sp_customer}{dmar_id})) {
	  			$found_business = 1;
	  			return $sp_customer;
	  			#print "Found Business\n";
  		} elsif (lc($esl_business) eq lc($account_reg->{$sp_customer}{dmar_company})) {
	  			$found_business = 1;
	  			return $sp_customer;
	  			#print "Found Business\n";

  		} elsif ($sp_customer =~ /^$esl_business$/i) {
				$found_business = 1;
                return $sp_customer;
		}

		}
	}
}


sub get_acf_penetration {
	my ($data_hash,$status,$type) = @_;
	my %temp_keys=();

	##
	$temp_keys{TOTAL_NODES} = 0;
	$temp_keys{ACF_ELIGIBLE}=0;
	$temp_keys{ACF_ENROLLED}=0;
	$temp_keys{ACF_PASS}=0;
	$temp_keys{ACF_WARNING}=0;
	$temp_keys{ACF_FAIL}=0;
	$temp_keys{ACF_ETP}=0;
	$temp_keys{ACF_NOT_ELIGIBLE}=0;

	foreach my $fqdn (sort keys %{$data_hash}) {

		if ($status =~ /^prd$/i) { next if ($data_hash->{$fqdn}{STATUS} !~ /in production/i); }
		if ($status =~ /^nonprd$/i) { next if ($data_hash->{$fqdn}{STATUS} =~ /in production/i); }
		if ($type !~ /all/i) { next if ($data_hash->{$fqdn}{OS} !~ /$platform{"$type"}/i); }

		##Total Nodes
		$temp_keys{TOTAL_NODES}++;
		if ($type !~ /esx|other|storage/i) {
			if ($data_hash->{$fqdn}{OS} !~ /$om_not_supported/i) {
				if ($data_hash->{$fqdn}{ACF_ETP} eq 1) { $temp_keys{ACF_ETP}++; }
				$temp_keys{ACF_ELIGIBLE}++ if ($data_hash->{$fqdn}{ACF_ETP} ne 1);
				if ($data_hash->{$fqdn}{ACF_ETP} ne 1) {
						$temp_keys{ACF_ENROLLED}++ if ($data_hash->{$fqdn}{ACF_STATUS} =~ /^installed/i);
						$temp_keys{ACF_PASS}++ if ($data_hash->{$fqdn}{ACF_RATING} =~ /pass/i);
						$temp_keys{ACF_FAIL}++ if ($data_hash->{$fqdn}{ACF_RATING} =~ /fail/i);
				}

			} else {
				$temp_keys{ACF_NOT_ELIGIBLE}++;
			}
		} else {
			if ($data_hash->{$fqdn}{ACF_ETP} eq 1) { $temp_keys{ACF_ETP}++; }
		}
	}

			$temp_keys{PERCENT_ACF} = 0;
			$temp_keys{PERCENT_ACF_COMPLIANCE} = 0;

		if ($temp_keys{TOTAL_NODES} > 0) {
			if ($temp_keys{ACF_ELIGIBLE} > 0) {
				$temp_keys{PERCENT_ACF} = sprintf "%d", eval { $temp_keys{ACF_ENROLLED} / $temp_keys{ACF_ELIGIBLE} * 100; };
				$temp_keys{PERCENT_ACF_COMPLIANCE} = sprintf "%d", eval { ($temp_keys{ACF_PASS}) / $temp_keys{ACF_ELIGIBLE} * 100; };
				$temp_keys{TOTAL_ACF_PASS} = $temp_keys{ACF_PASS};
				$temp_keys{TOTAL_ACF_FAIL} = $temp_keys{ACF_FAIL};
			} else {
				$temp_keys{PERCENT_ACF}=100;
				$temp_keys{PERCENT_ACF_COMPLIANCE}=100;
				$temp_keys{TOTAL_ACF_PASS} = 0;
				$temp_keys{TOTAL_ACF_FAIL} = 0;
			}

		}

		foreach my $hkey (sort keys %temp_keys) {
			if ($temp_keys{$hkey} eq "") { $temp_keys{$hkey} = 0 }
		}
		return \%temp_keys;
}


sub account_in_scope
{
	my ($customer, $account_reg, $type, $filter) = @_;

	$customer = lc($customer);

	$filter=~s/^(.*?)\:(.*?)$/$2/;

	my $found = 0;

	if (exists($account_reg->{$customer}{$type})) {
		if (ref($account_reg->{$customer}{$type}) =~ /array/i) {
			foreach my $x (@{$account_reg->{$customer}{$type}}) {
				if ($filter eq $x) {
					$found = 1;
					last;
				}
			}
		} else {

		  #print "$customer : $filter : 	$type : $account_reg->{$customer}{$type}<br>";
			if ($filter eq $account_reg->{$customer}{$type}) {
				$found = 1;
			}
		}
	}
	#print "$customer($filter) is $found\n";
	return $found;
}


###############################################################################
# save_hash
#
# inputs
#     $file_name - name of file to store hash structure in (aka cache file)
#     $hashref - reference to data structure (normnally a hash) to store

#
# returns
#     none
#
# Algorithm
#  USes Data::Dumper module to write data structure to file
###############################################################################
sub save_hash
{
   my ($fl,$hash_ref,$folder,$nosat) =@_;
   my $file;

   #$hash_ref->{CACHE_SYNC_TIME} = get_current_time();
   if ($folder eq "") {
   	$file = "$cache_dir/$fl";
   	make_path($cache_dir) if (not -r $cache_dir);

   } else {
   	$file = "$folder/$fl";
   	make_path($folder) if (not -r $folder);

   }




   my $pid = $$;

   if (scalar(keys %$hash_ref) > 0 || $folder =~ /by_customer/i || $fl =~ /build/i) {
      print STDERR "Saving Hash $fl to $file\n";

   		my ($hashref,$str,$out,$res1,$res2);
   		if ($fl =~ /account_|temp/i) {
	   		$str = Data::Dumper->Dump([ \%$hash_ref ], [ '$hashref' ]);
	  	} else {
	  		$str = "ASCII Cache File storing got depricated from OC 4.0 onwards due to performance issues."
	  	}
	   	$out = new FileHandle ">$file.build.$pid";
	   	print $out $str;
	   	close $out;
			#$res1 = `/bin/mv -f $file.build $file 2>&1`;
			move("$file.build.$pid", "$file");
			store $hash_ref, "$file.storable.build.$pid";
			move("$file.storable.build.$pid", "$file.storable");


		  #---
			my $cfg = read_config();
			my $local_server = hostname();
			#if ($local_server !~ /\./) { $local_server = hostfqdn(); }
			chomp $local_server;
			my $src_file = "$file.storable";
			my $tgt_dir = $src_file;
			$tgt_dir =~ s/^(.*)\/.*?$/$1/g;


#			if ($cfg->{DATACOLLECTION_SATELLITE} =~ /$local_server/i and not defined($nosat)) {
#				### Data Collection Satellites need to save to MAster (632)
#				my $tick = time();
#				my $cmd = "/usr/bin/rsync -av " . "\"$src_file\" " . 'root@' . "$cfg->{DATACOLLECTION_MASTER}:$tgt_dir/";
#				my $result = system("$cmd");
#				printf  "%s took %d\n", $cmd, time()-$tick;
#			}

	} else {
		print STDERR "NOT Saving Hash $fl to $file as it has no elements\n";
	}
}


sub save_json
{
   my ($fl,$hash_ref,$folder) =@_;
   my $file;

   #$hash_ref->{CACHE_SYNC_TIME} = get_current_time();
   if ($folder eq "") {
   	$file = "$cache_dir/$fl";
   	make_path($cache_dir) if (not -r $cache_dir);

   } else {
   	$file = "$folder/$fl";
   	make_path($folder) if (not -r $folder);

   }




   my $pid = $$;

   if (scalar(keys %$hash_ref) > 0 || $folder =~ /by_customer/i || $fl =~ /build/i) {
      print STDERR "Saving Hash $fl to JSON $file\n";

   		my ($hashref,$str,$out,$res1,$res2);
#   		if ($fl =~ /account_|temp|l1/i) {
#	   		$str = Data::Dumper->Dump([ \%$hash_ref ], [ '$hashref' ]);
#	  	} else {
#	  		$str = "ASCII Cache File storing got depricated from OC 4.0 onwards due to performance issues."
#	  	}
#	   	$out = new FileHandle ">$file.build.$pid";
#	   	print $out $str;
#	   	close $out;
#			#$res1 = `/bin/mv -f $file.build $file 2>&1`;
#			move("$file.build.$pid", "$file");


			#store $hash_ref, "$file.json.build.$pid";

			my $json = JSON->new->allow_nonref;
			my $json_data = $json->pretty->encode($hash_ref);
			my $json_data = encode_utf8( $json_data );

			open(OUTFILE,">$file.json.build.$pid");
			print OUTFILE $json_data;
			close(OUTFILE);

			move("$file.json.build.$pid", "$file.json");


		  #---
			my $cfg = read_config();
			my $local_server = hostname();
			#if ($local_server !~ /\./) { $local_server = hostfqdn(); }
			chomp $local_server;
			my $src_file = "$file.json";
			my $tgt_dir = $src_file;
			$tgt_dir =~ s/^(.*)\/.*?$/$1/g;


#			if ($cfg->{DATACOLLECTION_SATELLITE} =~ /$local_server/i) {
#
#				# Data Collection Satellites need to save to MAster (632)
#				my $tick = time();
#				my $cmd = "/usr/bin/rsync -av " . "\"$src_file\" " . 'root@' . "$cfg->{DATACOLLECTION_MASTER}:$tgt_dir/";
#				my $result = system("$cmd");
#				printf  "%s took %d\n", $cmd, time()-$tick;
#
#			}

	} else {
		print STDERR "NOT Saving Hash $fl to JSON $file as it has no elements\n";
	}
}

########################################################################
#
# save_aws_bucket
# Saves a file to an AWS S3 Bucket. Uses the default AWS Access ID and Secret Key as configured in
# the oc_master.cfg file.
# Inputs: Local file (Full Path), S3 Bucket, Folder in S3 Bucket, New file name (optional)
#
#
#
#
#
########################################################################
#sub save_aws_bucket {
#	my $cfg = read_config();
#	my ($local_file , $bucketname, $folder_path, $new_file) = @_;
#	my $just_file = $local_file;
#	($just_file)= $local_file=~m/.*\/(.*)$/;
#	$new_file= $just_file if (not defined($new_file));
#	use Crypt::CBC;
#	#Set the Cipher Key
#	my $cipher = Crypt::CBC->new( 	-key    => 'DXC BigFix Collectory Key',
#  	                        			 -cipher => 'Blowfish',
#    	                     );
#	$cipher->start('decrypting');
#	my $encrypted_key_cfg = "$cfg->{AWS_SECRET_KEY}";
#	usage("You must add a AWS_SECRET_KEY to the oc_master.cfg file.\nRun cmds/set_aws_key.pl to add a Key.") if(not defined($encrypted_key_cfg) or $encrypted_key_cfg=~/^\s*$/);
#	my $AWS_SECRET_KEY = $cipher->decrypt_hex("$encrypted_key_cfg");
#
#	my $ciphertext = $cipher->finish();
#
#
#	print "ID: $cfg->{AWS_ACCESS_ID}\nSECRET: $AWS_SECRET_KEY\nBucket: $bucketname\n";
#	$ENV{HTTPS_PROXY} = "$cfg->{AWS_PROXY}" if(defined($cfg->{AWS_PROXY}));
#
#	use Net::Amazon::S3;
#	my $s3 = Net::Amazon::S3->new({
#	         aws_access_key_id     => $cfg->{AWS_ACCESS_ID},
#        	 aws_secret_access_key => $AWS_SECRET_KEY,
#        	 #role_arn =>"arn:aws:iam::681167274649:role/dxc_oc_remote_collector",
#        	 #use_iam_role =>1,
#        	 timeout								=>30
#	});
#
#	my $bucket = $s3->bucket($bucketname);
#
#	my $response = $s3->buckets;
#	$folder_path.=$new_file;
#	my $s3_file= $local_file;
#	print "Copying $local_file to S3 location:$bucketname/$folder_path\n";
#	#Copy the File to the S3 Bucket
#	$bucket->add_key_filename( $folder_path, $local_file,
#    { content_type => 'text/plain', },	) or die $s3->err . ": " . $s3->errstr;
#
#}


#######################
#
#Set AWS Secret Key
#
#####################
sub get_secret_key {
	use Crypt::CBC;
	my $cipher = Crypt::CBC->new( 	-key    => 'DXC BigFix Collectory Key',
  	                        			 -cipher => 'Blowfish',
    	                     );
	print "aws secret key: ";
	#my $secret_key = prompt "aws secret key: ", -echo => '*'; # from IO::Prompter
	my $secret_key = <STDIN>;
	chomp($secret_key);


	$cipher->start('encrypting');
	my $enc_password =  $cipher->encrypt_hex($secret_key);
	my $ciphertext = $cipher->finish();
	my $filename = "$cfg_dir/oc_master.cfg";


	open(IN, $filename);
	my @file = <IN>;
	close(IN);

	my @new_file;
	my $cfg_secret_key;

	my $new_ln;
	foreach my $ln (@file){
		chomp;
    if ($ln =~ /AWS_SECRET_KEY/){
    	($cfg_secret_key)=$ln=~ /^\s*.*?\s*\=\s*(.*?)\s*$/;
    	$new_ln="AWS_SECRET_KEY=".$enc_password."\n";
    } else{
    	$new_ln= $ln;
    }
    push @new_file, $new_ln;
	}

	open(OUT, ">$filename");
	foreach my $line (@new_file){
		print OUT $line;
	}
	close(OUT);

}


##############################################################################
# get_filtered_accounts
#
# For APJ Region : Any user from Domain ASIAPACIFIC can see all apj region
# accounts. Otherwise the list will only return accounts mapped to the user
# in the user_companies cache -  created from a combination of ESL and NGDM
# Delivery Map assigned accounts.
#
# Inputs: none passed in - Env Variables from HTTP Headers only
# Output - Filtered Account Register
###############################################################################
sub get_filtered_accounts
{
       my $ntdomain = (split ':', $ENV{HTTP_PF_AUTH_NTUSERDOMAINID})[0];
       my $user = lc($ENV{OC_AUTH_UID});

	my @list = ('account_reg');
	my %cache = load_cache(\@list);
	my %account_reg = %{$cache{account_reg}};

	return %account_reg if(!$use_account_filter);

	## Return asap for golden ticket users
	my $ua_cfg = read_user_access_config();
	my $has_ua_cfg = defined($ua_cfg->{$user});

  if ($ua_cfg->{$user}{oc} =~ /all/i) {

  	return %account_reg ;
  }


	my %filtered_accounts;
	my %allowed_region;
	$allowed_region{ASIAPACIFIC} = 'anz';

	my @list = ('user_companies');
	my %cache_2 = load_cache(\@list);
	my %uc = %{$cache_2{user_companies}};

	# if user_companies file doesnt exist - we need to create it
	# This shouldnt normally happen - users should have normally had get_user.pl call done first.
	if (not exists($uc{$user})) {
	 	@list = ('user_companies_all');
	 	my %cache = load_cache(\@list);
	 	my %user_companies_all = %{$cache{user_companies_all}};
	 	if (defined($user_companies_all{$user})) {
	 		$uc{$user} = $user_companies_all{$user};
	 		save_hash("cache.user_companies", \%uc);
	 	}
	}

	if ($has_ua_cfg) {
		@list = ('l1_account_grouping');
		%user_cache = load_cache(\@list) if(!%user_cache);
		my %l1_account_grouping = %{$user_cache{l1_account_grouping}};
		# Process user_access
		if(ref($ua_cfg->{$user}{oc}) eq 'ARRAY') {
			if ($#{$ua_cfg->{$user}{oc}} >= 0) {
				foreach my $token (@{$ua_cfg->{$user}{oc}}) {
					if (defined($account_reg{$token})) {
						$filtered_accounts{$token} = $account_reg{$token};
					} elsif (defined($l1_account_grouping{$token})) {
						foreach my $check_customer (@{$l1_account_grouping{$token}}) {
							$filtered_accounts{$check_customer} = $account_reg{$check_customer};
						}
					}
				}
			}
		} else {
			my $token = $ua_cfg->{$user}{oc};

			if (defined($account_reg{$token})) {
				$filtered_accounts{$token} = $account_reg{$token};
			} elsif (defined($l1_account_grouping{$token})) {
				foreach my $check_customer (@{$l1_account_grouping{$token}}) {
					$filtered_accounts{$check_customer} = $account_reg{$check_customer};
				}
			}
		}
	}



	foreach my $customer (keys %account_reg)
	{
		if($allowed_region{$ntdomain})
		{
			if($account_reg{$customer}{oc_region} =~ /$allowed_region{$ntdomain}/)
			{
				$filtered_accounts{$customer} = $account_reg{$customer};
				next;
			}
		}
		if($uc{$user}{$customer})
		{
			$filtered_accounts{$customer} = $account_reg{$customer};
		}
	}

	return %filtered_accounts;
}

###############################################################################
# check_cmc_update
#
# Check for access to golden secret tiles and services
#
###############################################################################
sub check_cmc_update
{
	my $user = lc($ENV{OC_AUTH_UID});
	return 1; ## If allowed cmc config
}



###############################################################################
# check_golden_ticket
#
# Check for access to golden secret tiles and services
#
###############################################################################
sub check_golden_ticket
{
	my $ntdomain = (split ':', $ENV{HTTP_PF_AUTH_NTUSERDOMAINID})[0];
	my $user = lc($ENV{OC_AUTH_UID});

	my $ua_cfg = read_user_access_config();
	return 1 if ($ua_cfg->{$user}{oc} =~ /all/);
}


###############################################################################
# check_account_access
#
# To be called for every account specific call
# checks if a customer is assigned in or check if grouping allows access
#
# Input: customer name
# output 0 for no or 1 for yes
###############################################################################
sub check_account_access
{
	my ($customer) = @_;

	return 1 if (!$use_account_filter);

	my $ntdomain = (split ':', $ENV{HTTP_PF_AUTH_NTUSERDOMAINID})[0];
	my $user = lc($ENV{OC_AUTH_UID});



	my $ua_cfg = read_user_access_config();
	return 1 if ($ua_cfg->{$user}{oc} =~ /^developer-all$/);

	#my $account_access_restrictions = LoadFile("/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/cfg/account_access_restrictions.yaml");

	return 1 if ($ua_cfg->{$user}{oc} =~ /^all$/);
	return 1 if ($ua_cfg->{$user}{oc} =~ /^$customer$/);

	## Process Groups
	my @list = ('l1_account_grouping');
	%user_cache = load_cache(\@list) if(!%user_cache);
	my %l1_account_grouping = %{$user_cache{l1_account_grouping}};

	my %allowed_region;
	$allowed_region{ASIAPACIFIC} = 'anz';


	if(ref($ua_cfg->{$user}{oc}) eq 'ARRAY') {
		if ($#{$ua_cfg->{$user}{oc}} >= 0) {
			foreach my $token (@{$ua_cfg->{$user}{oc}}) {

				return 1 if ($token eq $customer);
				#else
				if (defined($l1_account_grouping{$token})) {
					foreach my $check_customer (@{$l1_account_grouping{$token}}) {
						return 1 if($customer eq $check_customer);
					}
				}
			}
		}
	} else {
		my $token = $ua_cfg->{$user}{oc};
		if (defined($l1_account_grouping{$token})) {
			foreach my $check_customer (@{$l1_account_grouping{$token}}) {
				return 1 if($customer eq $check_customer);
			}
		}
	}


	if($allowed_region{$ntdomain})
	{
		my $group = "region:$allowed_region{$ntdomain}";
		foreach my $check_customer (@{$l1_account_grouping{$group}})
		{
         #print "checking: $check_customer, $user, $ntdomain\n";
			return 1 if($customer eq $check_customer);
		}
	}
	my %user_cache_2;

	my @list = ('user_companies');
  %user_cache_2 = load_cache(\@list) if(!%user_cache_2);
	my %uc = %{$user_cache_2{user_companies}};

	# This shouldnt normally happen - users should have normally had get_user.pl call done first.
	if (not exists($uc{$user})) {
	 	my @list = ('user_companies_all');
	 	my %cache = load_cache(\@list);
	 	my %user_companies_all = %{$cache{user_companies_all}};
	 	if (defined($user_companies_all{$user})) {
	 		$uc{$user} = $user_companies_all{$user};
	 		save_hash("cache.user_companies", \%uc);
	 	}
	}

	return 1 if ($uc{$user}{$customer});
	return 0;
}

###############################################################################
# connect_to_oc_db
#
# Create connection to Operations Center database
#
###############################################################################
sub connect_to_oc_db
{
	# Establish connection to database
  my $data_source = q/dbi:ODBC:CONTROLSERVER/;
  my $user = q/OCSQLUser/;
  #my $password = 'User-0perat!Ons_2O17#';
  my $password = 'Oper@t!0ns_User-2016$';
  my $dbh = DBI->connect($data_source, $user, $password)
   or die '<p>Cannot connect to ' . $data_source . ':' . $DBI::errstr . '</p>';

  return 	$dbh;
}


###########################################
# collector_cache_health_test
#
# Healthcheck function called from a collector perl script
#
# $cache is an Array refrence to a triple tild seperated filename, age in hours,  minimum size in MB, minimum lines in file(raw cache file)
#
###########################################
sub collector_cache_health_test {

	my ($cache)= @_;
	my @collector_hc_files;

	my ($caller_name)= (caller(0))[1];
	my ($caller_name_file) =$caller_name =~m/\/(\w*.\w*)$/;
	my $just_file_name =$caller_name_file;
	$just_file_name=~s/\W/_/g;
	my $hc_cfg_file_name =$just_file_name.".cfg";

	#print "Checking for Healthcheck cfg file $health_cfg_dir/$hc_cfg_file_name\n";
	if(-e "$health_cfg_dir/$hc_cfg_file_name"){
		open(HCCFG, "<$health_cfg_dir/$hc_cfg_file_name");
		while(<HCCFG>) {
			chomp;
			next if (/^\s*#/);
      #Truncate any comments on ends of config lines
    	s/^(.*?)\s+\#//;

			if (/^COLLECTOR_HC_FILES/) {
				my ($hc_file) = m/^COLLECTOR_HC_FILES\~\~\~(.*?)$/;
				#print "HCFILE: $hc_file\n";
				push @collector_hc_files, $hc_file;
			}

		}
		close(HCCFG);

		$cache=\@collector_hc_files if(scalar(@collector_hc_files) >0);

	}

	my $now = time();
	my %cache_health_test;
	foreach my $check (@$cache) {
		my ($file_name, $age, $size, $lines)= split(/\~\~\~/,$check);

		my $file = $file_name;
		$file = $file_name.".storable" if($file_name !~/rawcache/);
		$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{MODTIME} = (stat "$file")[9];
		$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{SIZE} = (stat "$file")[7];
		my $check_human_time = localtime($cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{MODTIME});
		my $check_size = $cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{SIZE};
		my $check_size_KB= sprintf "%d", $check_size/1024;
		my $check_size_MB= sprintf "%0.2f",$check_size_KB/1024;
		my $check_size_GB= sprintf "%0.2f",$check_size_MB/1024;

		my $diff_hours = sprintf "%d", ($now - $cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{MODTIME})/60/60;

		my $check_lines;
		#If value for lines is given
		if(defined($lines)){
			open(FL, $file);
			my @file=<FL>;
			close(FL);
			($check_lines) = scalar(@file);
			if($check_lines > $lines){
				$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{LINES_CHECK}= "PASS";
			} else{
				$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{LINES_CHECK}= "FAIL";
			}
			$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{LINES_DETAILS}= "Lines Threshold=$lines , Lines Checked=$check_lines ";
		}

		#Basic Size and Modtime Checks
		if (-e "$file") {
			$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{EXISTS} ="YES";
			if($diff_hours < $age){
				$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{AGE_CHECK}= "PASS";
			} else{
				$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{AGE_CHECK}= "FAIL";
			}
			if($check_size_MB >= $size){
				$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{SIZE_CHECK}= "PASS";
			} else{
				$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{SIZE_CHECK}= "FAIL";
			}

		}
		else{
			$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{EXISTS} ="NO";
			$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{SIZE_CHECK}= "N/A";
			$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{AGE_CHECK}= "N/A";
			$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{LINES_CHECK}= "N/A";
		}
		$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{SIZE_DETAILS}= "Size Threshold=$size"."MB, Size Checked=$check_size_MB"."MB ($check_size_KB"."KB $check_size_GB"."GB $check_size"."bytes) ";
		$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{AGE_DETAILS}= "Age Threshold=$age hours, Age Checked=$diff_hours hours ($check_human_time, $cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{MODTIME}) ";

	}
	#print Dumper \%cache_health_test;
	my $save_file= "cache.healthcheck_".$just_file_name;
	save_hash ($save_file,\%cache_health_test,"$cache_dir"."/healthchecks" );
	#return %cache_health_test;

}

############################################
# l2_cache_health_test
#
# Healthcheck function called from l2_reports/ create_l2 scripts
#
# $cache is an Array refrence to triple tild seperated l2 Cache file name, Maximum Age in Hours,  Min Size in MB
# $samples is an Array refrence to triple tild seperated l2 Cache file name, Customer name, Metric KEY as a String, Max Value Min Value
# $splits is an Array refrence to triple tild seperated directory the split files are in, pattern to match the split filename, expected number of files, Max age in hours
#
##################################################
sub l2_cache_health_test {


	my ($cache, $samples,$splits)= @_;
	my @l2_hc_files;
	my @l2_hc_metric;
	my @l2_hc_split;
	my @hc_custom;

	my ($caller_name)= (caller(0))[1];
	my ($caller_name_file) =$caller_name =~m/\/(\w*.\w*)$/;
	my $just_file_name =$caller_name_file;
	$just_file_name=~s/\W/_/g;
	my $hc_cfg_file_name =$just_file_name.".cfg";

	#print "Checking for Healthcheck cfg file $health_cfg_dir/$hc_cfg_file_name\n";
	if(-e "$health_cfg_dir/$hc_cfg_file_name"){
		open(HCCFG, "<$health_cfg_dir/$hc_cfg_file_name");
		while(<HCCFG>) {
			chomp;
			next if (/^\s*#/);
      #Truncate any comments on ends of config lines
    	s/^(.*?)\s+\#//;

			if (/^L2_HC_FILES/) {
				my ($hc_file) = m/^L2_HC_FILES\~\~\~(.*?)$/;
				#print "HCFILE: $hc_file\n";
				push @l2_hc_files, $hc_file;
			}
			if (/^L2_HC_METRIC/) {
				my ($hc_metric) = m/^L2_HC_METRIC\~\~\~(.*?)$/;
				push @l2_hc_metric, $hc_metric;
			}
			if (/^L2_HC_SPLIT/) {
				my ($hc_split) = m/^L2_HC_SPLIT\~\~\~(.*?)$/;
				push @l2_hc_split, $hc_split;
			}
		}
		close(HCCFG);

		$cache=\@l2_hc_files if(scalar(@l2_hc_files)>0);
		$samples=\@l2_hc_metric if(scalar(@l2_hc_metric)>0);
		$splits=\@l2_hc_split if(scalar(@l2_hc_split)>0);
	}

	#L2 Cache file check
	my $now = time();
	my %cache_health_test;
	foreach my $check (@$cache) {
		my ($file_name, $age, $size)= split(/\~\~\~/,$check);
		my $file = $file_name.".storable";
		$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{MODTIME} = (stat "$file")[9];
		$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{SIZE} = (stat "$file")[7];
		my $check_human_time = localtime($cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{MODTIME});
		my $check_size =$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{SIZE};
		my $check_size_KB= sprintf "%d", $check_size/1024;
		my $check_size_MB= sprintf "%0.2f", $check_size_KB/1024;
		my $check_size_GB= sprintf "%0.2f", $check_size_MB/1024;

		my $diff_hours = sprintf "%d", ($now - $cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{MODTIME})/60/60;

		#Basic Size and Modtime Checks
		if (-e "$file") {
			$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{EXISTS} ="YES";
			if($diff_hours < $age){
				$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{AGE_CHECK}= "PASS";
			} else{
				$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{AGE_CHECK}= "FAIL";
			}
			if($check_size_MB >= $size){
				$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{SIZE_CHECK}= "PASS";
			} else{
				$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{SIZE_CHECK}= "FAIL";
			}
		}
		else{
			$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{EXISTS} ="NO";
			$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{SIZE_CHECK}= "N/A";
			$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{AGE_CHECK}= "N/A";
		}
		$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{SIZE_DETAILS}= "Size Threshold=$size"."MB, Size Checked=$check_size_MB"."MB ($check_size_KB"."KB $check_size_GB"."GB $check_size"."bytes) ";
		$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{AGE_DETAILS}= "Age Threshold=$age hours, Age Checked=$diff_hours hours ($check_human_time, $cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{MODTIME}) ";
	}

	#L2 Cache sample Customer data check
	foreach my $check (@$samples){
		my ($file, $metric, $value)= split(/\~\~\~/,$check);
		my ($minvalue,$maxvalue)=split(/\,/,$value);
		my $sys = load_cache_byFile($file);
		my %loaded_cache = %{$sys};
		my $metric_check ='$loaded_cache'.$metric;
		my $check_value= eval "$metric_check" ||0;

		if($check_value >= $minvalue and $check_value <= $maxvalue ){
			$cache_health_test{$just_file_name}{METRIC_CHECK}{$file}{METRIC}{$metric}="PASS";
		}else{
			$cache_health_test{$just_file_name}{METRIC_CHECK}{$file}{METRIC}{$metric}="FAIL";
		}
		$cache_health_test{$just_file_name}{METRIC_CHECK}{$file}{METRIC_DETAILS}{$metric}= "Checked for metric value greater than $minvalue and less than $maxvalue. Found:$check_value ";
	}

	#L2 Split check
	foreach my $check (@$splits){
		my ($file_dir,$pattern, $count, $age)= split(/\~\~\~/,$check);
		opendir (DIR, $file_dir);
		my @dir = readdir DIR;
		my $check_count;
		my @ages;
		foreach my $f (@dir){
			$check_count++ if($f=~/$pattern.*\.storable/);
			if(not ($check_count % 100)){
				my ($agecheck) = (stat("$file_dir$f"))[9];

				push @ages, $agecheck;
			}
		}
		my $mean= (map$a+=$_/@ages,@ages)[-1];
		my $now = time();
		my $diff_hours = sprintf "%d", ($now - $mean)/60/60;
		my $filepattern= $file_dir.$pattern;

		if ($diff_hours > $age){
			$cache_health_test{$just_file_name}{SPLIT_CHECK}{$file_dir}{AGE_CHECK}{$pattern}="FAIL";
		}
		else{
			$cache_health_test{$just_file_name}{SPLIT_CHECK}{$file_dir}{AGE_CHECK}{$pattern}="PASS";
		}
		if($check_count <$count){
			$cache_health_test{$just_file_name}{SPLIT_CHECK}{$file_dir}{SPLIT_PATTERN}{$pattern}="FAIL";
		}else{
			$cache_health_test{$just_file_name}{SPLIT_CHECK}{$file_dir}{SPLIT_PATTERN}{$pattern}="PASS";
		}
		$cache_health_test{$just_file_name}{SPLIT_CHECK}{$file_dir}{SPLIT_DETAILS}{$pattern}= "Checked for files matching $pattern expecting greater than $count. Found:$check_count ";
		$cache_health_test{$just_file_name}{SPLIT_CHECK}{$file_dir}{SPLIT_AGE_DETAILS}{$pattern}= "Average age of files matching $pattern expected to be less than $age hrs. Found:$diff_hours hrs. ";


	}
	#print Dumper \%cache_health_test;
	my $save_file= "cache.healthcheck_".$just_file_name;
	save_hash ($save_file,\%cache_health_test,"$cache_dir"."/healthchecks" );

}


############################################
# l1_cache_health_test
#
# Healthcheck function called my l1_reports/create_l1 scripts
#
# $cache is an Array refrence to triple tild seperated l1 Cache file name,  Minimum Age in hours, Maximum Size in MB
# $samples is an Array refrence to triple tild seperated l1 Cache file name, Customer name, Metric KEY as a String, Max Value Min Value
# $splits is an Array refrence to triple tild seperated Script that creates the splits, directory the split files are in, pattern to match the split filename, expected number of files, Max age in hours
#
##################################################
sub l1_cache_health_test {

	my ($cache, $samples,$splits)= @_;
	my @l1_hc_files;
	my @l1_hc_metric;
	my @l1_hc_split;
	my @hc_custom;

	my ($caller_name)= (caller(0))[1];
	my ($caller_name_file) =$caller_name =~m/\/(\w*.\w*)$/;
	my $just_file_name =$caller_name_file;
	$just_file_name=~s/\W/_/g;
	my $hc_cfg_file_name =$just_file_name.".cfg";

	#print "Checking for Healthcheck cfg file $health_cfg_dir/$hc_cfg_file_name\n";
	if(-e "$health_cfg_dir/$hc_cfg_file_name"){
		open(HCCFG, "<$health_cfg_dir/$hc_cfg_file_name");
		while(<HCCFG>) {
			chomp;
			next if (/^\s*#/);
      #Truncate any comments on ends of config lines
    	s/^(.*?)\s+\#//;

			if (/^L1_HC_FILES/) {
				my ($hc_file) = m/^L1_HC_FILES\~\~\~(.*?)$/;
				#print "HCFILE: $hc_file\n";
				push @l1_hc_files, $hc_file;
			}
			if (/^L1_HC_METRIC/) {
				my ($hc_metric) = m/^L1_HC_METRIC\~\~\~(.*?)$/;
				push @l1_hc_metric, $hc_metric;
			}
			if (/^L1_HC_SPLIT/) {
				my ($hc_split) = m/^L1_HC_SPLIT\~\~\~(.*?)$/;
				push @l1_hc_split, $hc_split;
			}
		}
		close(HCCFG);

		$cache=\@l1_hc_files if(scalar(@l1_hc_files)>0);
		$samples=\@l1_hc_metric if(scalar(@l1_hc_metric)>0);
		$splits=\@l1_hc_split if(scalar(@l1_hc_split)>0);
	}


	#L1 Cache file check
	my $now = time();
	my %cache_health_test;
	foreach my $check (@$cache) {
		my ($file_name, $age, $size)= split(/\~\~\~/,$check);
		my $file = $file_name.".storable";

		$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{MODTIME} = (stat "$file")[9];
		$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{SIZE} = (stat "$file")[7];
		my $check_human_time = localtime($cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{MODTIME});
		my $check_size =$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{SIZE};
		my $check_size_KB= sprintf "%d", $check_size/1024;
		my $check_size_MB= sprintf "%0.2f", $check_size_KB/1024;
		my $check_size_GB= sprintf "%0.2f", $check_size_MB/1024;

		my $diff_hours = sprintf "%d", ($now - $cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{MODTIME})/60/60;

		#Basic Size and Modtime Checks
		if (-e "$file") {
			$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{EXISTS} ="YES";
			if($diff_hours < $age){
				$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{AGE_CHECK}= "PASS";
			} else{
				$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{AGE_CHECK}= "FAIL";
			}
			if($check_size_MB >= $size){
				$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{SIZE_CHECK}= "PASS";
			} else{
				$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{SIZE_CHECK}= "FAIL";
			}
		}
		else{
			$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{EXISTS} ="NO";
			$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{SIZE_CHECK}= "N/A";
			$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{AGE_CHECK}= "N/A";
		}
		$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{SIZE_DETAILS}= "Size Threshold=$size"."MB, Size Checked=$check_size_MB"."MB ($check_size_KB"."KB $check_size_GB"."GB $check_size"."bytes) ";
		$cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{AGE_DETAILS}= "Age Threshold=$age hours, Age Checked=$diff_hours hours ($check_human_time, $cache_health_test{$just_file_name}{CACHE_CHECK}{$file_name}{MODTIME}) ";
	}

	#L1 Cache sample Customer data check
	foreach my $check (@$samples){
		my ($file, $metric, $value)= split(/\~\~\~/,$check);
		my ($minvalue,$maxvalue)=split(/\,/,$value);
		my $sys = load_cache_byFile($file);
		my %loaded_cache = %{$sys};
		my $metric_check ='$loaded_cache'.$metric;
		my $check_value= eval "$metric_check" ||0;

		if($check_value >= $minvalue and $check_value <= $maxvalue ){
			$cache_health_test{$just_file_name}{METRIC_CHECK}{$file}{METRIC}{$metric}="PASS";
		}else{
			$cache_health_test{$just_file_name}{METRIC_CHECK}{$file}{METRIC}{$metric}="FAIL";
		}
		$cache_health_test{$just_file_name}{METRIC_CHECK}{$file}{METRIC_DETAILS}{$metric}= "Checked for metric value greater than $minvalue and less than $maxvalue. Found:$check_value ";
	}

	#L1 Split check
	foreach my $check (@$splits){
		my ($file_dir,$pattern, $count, $age)= split(/\~\~\~/,$check);
		opendir (DIR, $file_dir);
		my @dir = readdir DIR;
		my $check_count;
		my @ages;
		foreach my $f (@dir){
			$check_count++ if($f=~/$pattern.*\.storable/);
			if(not ($check_count % 100)){
				my ($agecheck) = (stat("$file_dir$f"))[9];
				push @ages, $agecheck;
			}
		}
		my $mean= (map$a+=$_/@ages,@ages)[-1];
		my $now = time();
		my $diff_hours = sprintf "%d", ($now - $mean)/60/60;
		my $filepattern= $file_dir.$pattern;

		if ($diff_hours > $age){
			$cache_health_test{$just_file_name}{SPLIT_CHECK}{$file_dir}{AGE_CHECK}{$pattern}="FAIL";
		}
		else{
			$cache_health_test{$just_file_name}{SPLIT_CHECK}{$file_dir}{AGE_CHECK}{$pattern}="PASS";
		}
		if($check_count <$count){
			$cache_health_test{$just_file_name}{SPLIT_CHECK}{$file_dir}{SPLIT_PATTERN}{$pattern}="FAIL";
		}else{
			$cache_health_test{$just_file_name}{SPLIT_CHECK}{$file_dir}{SPLIT_PATTERN}{$pattern}="PASS";
		}
		$cache_health_test{$just_file_name}{SPLIT_CHECK}{$file_dir}{SPLIT_DETAILS}{$pattern}= "Checked for files matching $filepattern expecting greater than $count. Found:$check_count ";
		$cache_health_test{$just_file_name}{SPLIT_CHECK}{$file_dir}{SPLIT_AGE_DETAILS}{$pattern}= "Checked for average file age less than $age hours. Found:Average age of $diff_hours hours.";
	}
	#print Dumper \%cache_health_test;
	#return %cache_health_test;
	my $save_file= "cache.healthcheck_".$just_file_name;
	save_hash ($save_file,\%cache_health_test,"$cache_dir"."/healthchecks" );

}

###########################################
# custom_health_test
#
# Healthcheck function called from anywhere
#
# $health is an Array refrence to a triple tild seperated custom check name, status, details of what this FAIL/PASS status means
#
###########################################
sub custom_health_test {

	my ($health)= @_;
	my @custom_health;
	my ($caller_name)= (caller(0))[1];
	my ($caller_name_file) =$caller_name =~m/\/(\w*.\w*)$/;
	my $just_file_name =$caller_name_file;
	$just_file_name=~s/\W/_/g;
	my $hc_cfg_file_name =$just_file_name."_custom.cfg";

	#print "Checking for Healthcheck cfg file $health_cfg_dir/$hc_cfg_file_name\n";
	if(-e "$health_cfg_dir/$hc_cfg_file_name"){
		open(HCCFG, "<$health_cfg_dir/$hc_cfg_file_name");
		while(<HCCFG>) {
			chomp;
			next if (/^\s*#/);
      #Truncate any comments on ends of config lines
    	s/^(.*?)\s+\#//;

			if (/^HC_CUSTOM/) {
				my ($hc_custom) = m/^HC_CUSTOM\~\~\~(.*?)$/;
				#print "HCFILE: $hc_file\n";
				push @custom_health, $hc_custom;
			}

		}
		close(HCCFG);

		$health=\@custom_health;

	}

	my $now = time();
	my %cache_health_test;
	foreach my $check (@$health) {
		my ($custom_name, $status, $details)= split(/\~\~\~/,$check);

		#Custom Healthcheck
		$cache_health_test{$just_file_name}{CUSTOM_CHECK}{$custom_name}{CUSTOM_STATUS}=$status;
		$cache_health_test{$just_file_name}{CUSTOM_CHECK}{$custom_name}{CUSTOM_DETAILS}=$details;
	}

	my $save_file= "cache.healthcheck_".$just_file_name."_custom";
	save_hash ($save_file,\%cache_health_test,"$cache_dir"."/healthchecks" );


}

sub s3_download_cache {
	my ($cache_file,$type,$bucket,$profile,$ssz_dir) = @_;
	my $cmd = "/usr/local/bin/aws s3 cp $bucket/$type/$cache_file $ssz_dir/$type/ --profile $profile";
	print "$cmd\n";
	my $result = `$cmd`;
	print "Result:$result\n";
}

sub get_pdxc_cache_files {

	my ($ins, $tile) = @_;

	use YAML::XS 'LoadFile';
	my $pdxc_cfg = LoadFile("$cfg_dir/oc_pdxc.yaml");

	foreach my $instance (keys %{$pdxc_cfg}) {
		next if ($instance !~ /$ins/i);
	  my $bucket = $pdxc_cfg->{$instance}{'s3_retrival_bucket'};
		my $profile = $pdxc_cfg->{$instance}{'s3_profile'};
		my $ssz_dir = $pdxc_cfg->{$instance}{'ssz_instance_dir'} . '/core_receiver';
		my $instance_url = $pdxc_cfg->{$instance}{'instance_url'};

		if (!-d $ssz_dir) { system("mkdir -p $ssz_dir"); }
		if (!-d "$ssz_dir/l2_cache") { system("mkdir -p $ssz_dir/l2_cache"); }


	  		#Copy the cfg files
				foreach my $source_dir (keys %{$pdxc_cfg->{$instance}{'tiles'}{$tile}}) {
					foreach my $cache_file (@{$pdxc_cfg->{$instance}{'tiles'}{$tile}{$source_dir}}) {
						if ($source_dir =~ /l2_cache/i) {
							s3_download_cache($cache_file,$source_dir,$bucket,$profile,$ssz_dir);
						}
					}
				}
	}
	print "get_pdxc_cache_files completd\n";
	return $pdxc_cfg;

}

sub update_pdxc_cache {
	my ($source_dir,$cache_file,$instance,$instance_url) = @_;
	print "In update_pdxc_cache\n";
	print "Updating cache file --- $source_dir, $cache_file, $instance, $instance_url\n";
	my %mapping;
	##################################################
	#
	# This section will look at all the Keys in a hash  regardless of it's structre
	# it checks the last key to see if it is a HTML, VALUE or COLOR then copies the entrire
	# structure to create a new value in the same spot with a new Key like <INSTANCE>_VALUE or <INSTANCE>_HTML
	#
	###################################################
	#use Test::utf8;

	#use Encode;
	## Look into the HASH and return all the Keys for each element
	my $pdxc_inc = load_cache_byFile("$source_dir/$cache_file");
	foreach my $customer (sort keys %{$pdxc_inc->{CUSTOMER}}) {
		$mapping{$customer}{INSTANCE} = $instance;
		$mapping{$customer}{INSTANCE_URL} = $instance_url;
		print $customer."\n";
		while (my @list = reach($pdxc_inc->{CUSTOMER}{$customer})) {
			my @x =@list;
			pop(@x);#Drop the last "Key" returned because it is the value

			#Get the Value from the hash using the keys returned
			my ($value) = deepvalue($pdxc_inc->{CUSTOMER}{$customer},@x);
			my $newkey_string='$pdxc_inc->{CUSTOMER}{'."'".$customer."'".'}';
			my $key_string='$pdxc_inc->{CUSTOMER}{'."'".$customer."'".'}';
			my $src_string='$pdxc_inc->{CUSTOMER}{'."'".$customer."'".'}';
			if($value =~/cgi-bin/ or $x[-1] =~/VALUE|HTML|COLOR/){
				next if ($value=~/cgi-bin/ and  $value =~/\Q$instance_url\E/);
				#print "VALUE:$value\n";
				#Create a new litteral string (code) that will create the new Hash element we want
				foreach my $k(@x){
					if($k eq "HTML" or $k eq "VALUE" or $k eq "COLOR"){
						$newkey_string.="{'".$instance."_".$k."'}";
						$key_string.="{'".$k."'}";
						$src_string.="{'".$k."'}";
					}else{
						$key_string.="{'".$k."'}";
						$newkey_string.="{'".$k."'}";
						$src_string.="{'".$k."'}";
					}
				}
				$src_string.="{SRC}{".$instance."_VALUE}";
				#print '----------------------' . "$instance_url\n";
				#print 'Real Value-----------------------' . $value . "\n";
				my $newvalue= 'href="'.$instance_url.'/?url=/cgi-bin';
				$value=~s/href\=\"\/cgi-bin/$newvalue/;
				#print 'Changed Value-----------------------' . $value . "\n";
				my $newhref='a target="_self" href=';
				#$value=~s/a href\=/a target=\"_self\" href=/;
				$value=~s/a href\=/$newhref/;
				$newkey_string=~s/(\w)\'(\w)/$1\\\'$2/g;
				$key_string=~s/(\w)\'(\w)/$1\\\'$2/g;
				$src_string=~s/(\w)\'(\w)/$1\\\'$2/g;

				#print 'final value-----------------------' . $value . "\n";
				# Clean the string with quitemeta and eval it to create the new hash element
				#print "VALUE AFTER:$value\n";
				my $newcode = $newkey_string.'="'.quotemeta($value).'"';
				#my $ustring = decode( 'UTF-8', $newcode );
				#$newcode = encode('UTF-8', $ustring);
				$newcode = Encode::encode("utf8", $newcode);
				eval $newcode;
				print "NEWCODE:$newcode\n" if($@);
				print $@ if($@);
				my $code = $key_string.'="'.quotemeta($value).'"';
				#my $ustring = decode( 'UTF-8', $code );
				#$code = encode('UTF-8', $ustring);
				$code = Encode::encode("utf8", $code);
				eval $code;
				print $@ if($@);
				print "KEYSTRING:$code\n" if($@);
				#my $srccode = $src_string.'="'.quotemeta($pdxc_inc->{CUSTOMER}{$customer}{SRC}).'"';
				#my $ustring = decode( 'UTF-8', $srccode );
				#$srccode = encode('UTF-8', $ustring);
				#eval $srccode;
				#print $@ if($@);
				#print "SRCCODE:$srccode\n" if($@);
			}
		}
	}
	save_hash("$cache_file", \%{$pdxc_inc},"$source_dir");
	return \%mapping;
}


sub update_pdxc_ssz {
	my ($l2_cache, $pdxc_customer,$l2_url) = @_;
	print "Updating PDXC SSZ Totals\n";
	foreach my $customer (sort keys %$pdxc_customer) {
		print "$customer\n";
		my $instance = $pdxc_customer->{$customer}{INSTANCE};
		##################################################
		#
		# This section will look at all the Keys in a hash  regardless of it's structre
		# it checks the last key to see if it is a HTML, VALUE or COLOR then copies the entrire
		# structure to create a new value in the same spot with a new Key like <INSTANCE>_VALUE or <INSTANCE>_HTML
		#
		###################################################

		## Look into the HASH and return all the Keys for each element
		while (my @list = reach($l2_cache->{CUSTOMER}{$customer})) {
			my $last = $list[-1]	;
			my @x =@list;
			pop(@x);#Drop the last "Key" returned because it is the value

			#Get the Value from the hash using the keys returned
			my ($value) = deepvalue($l2_cache->{CUSTOMER}{$customer},@x);
			my $ssz_value_key_string='$l2_cache->{CUSTOMER}{'."'".$customer."'".'}';
			my $ssz_html_key_string='$l2_cache->{CUSTOMER}{'."'".$customer."'".'}';
			my $new_html_key_string='$l2_cache->{CUSTOMER}{'."'".$customer."'".'}';
			if($x[-1] eq "VALUE" and $value ne ""){
				#print "VALUE:$value\n";
				#Create a new litteral string (code) that will create the new Hash element we want
				foreach my $k(@x){
					if($k eq "VALUE" ){
						$ssz_value_key_string.="{'SSZ_".$k."'}";
						$ssz_html_key_string.="{'SSZ_HTML'}";
						$new_html_key_string.="{'HTML'}";
					}else{
						$ssz_value_key_string.="{'".$k."'}";
						$ssz_html_key_string.="{'".$k."'}";
						$new_html_key_string.="{'".$k."'}";
					}
				}
				my $total_value = $last;
				my @y = @x;
				$y[-1]="HTML";
				my $total_html = deepvalue($l2_cache->{CUSTOMER}{$customer},@y);
				$y[-1]=$instance."_VALUE";
				#print "INSTANCE VALUE:$y[-1]\n";
				my $p_value = deepvalue($l2_cache->{CUSTOMER}{$customer},@y);
				#print "PVALUE:$p_value\n";
				$y[-1]=$instance."_HTML";
				my $p_html = deepvalue($l2_cache->{CUSTOMER}{$customer},@y);

				my $ssz_value = sprintf("%.2f", $total_value) - sprintf("%.2f",$p_value);
				#print "SUM: $total_value - $p_value = $ssz_value\n";
				chomp($total_html);
				my ($s)= $total_html =~ m/\<a href\=\"(.*?)\"\>.*?$/;

				#print "--$s--\n";
				my $ssz_html = '<a href="' . $s . '">' . $ssz_value . '</a>';
				 $ssz_html=$total_html if($ssz_value==0);
				if ($total_html =~ /cgi-bin/i) {
					# Clean the string with quitemeta and eval it to create the new hash element
					$total_html = '<a href="/cgi-bin/GTOD_CC/l2_reports/'.$l2_url.'">' . $total_value . '</a>';

					$new_html_key_string=~s/(\w)\'(\w)/$1\\\'$2/g;
					$ssz_value_key_string=~s/(\w)\'(\w)/$1\\\'$2/g;
					$ssz_html_key_string=~s/(\w)\'(\w)/$1\\\'$2/g;
					my $sszcode = $new_html_key_string.'="'.quotemeta($total_html).'"';
					$sszcode = Encode::encode("utf8", $sszcode);
					eval $sszcode;
					print "NEWSSZHTML:$sszcode\n" if($@);
					my $sszcode = $ssz_value_key_string.'="'.quotemeta($ssz_value).'"';
					$sszcode = Encode::encode("utf8", $sszcode);
					eval $sszcode;
					print "SSZVALUE_KEY:$sszcode\n"  if($@);
					my $sszcode = $ssz_html_key_string.'="'.quotemeta($ssz_html).'"';
					$sszcode = Encode::encode("utf8", $sszcode);
					eval $sszcode;
					print "SSZHTML_KEY:$sszcode\n" if($@);

				}
			}
		}
	}

}


sub get_pdxc_instance {
	my ($tile_id) = @_;
	use YAML::XS 'LoadFile';
	my $pdxc_cfg = LoadFile("$cfg_dir/oc_pdxc.yaml");
	my @pdxc_instance;
	foreach my $instance (keys %{$pdxc_cfg}) {
		  my $bucket = $pdxc_cfg->{$instance}{'s3_retrival_bucket'};
			my $profile = $pdxc_cfg->{$instance}{'s3_profile'};
			my $ssz_dir = $pdxc_cfg->{$instance}{'ssz_instance_dir'};
		  my $instance_url = $pdxc_cfg->{$instance}{'instance_url'};

			#my $pdxc_inc = load_cache_byFile("$ssz_dir/core_receiver/l2_cache/cache.l2_incidents");
		  #my $pdxc_account_reg = load_cache_byFile("$ssz_dir/core_sender/cache.account_register");
		  #if ($pdxc_account_reg->{$customer}) {
		  	 if ($pdxc_cfg->{$instance}{'tiles'}{$tile_id}) {
		  	 		push @pdxc_instance, $instance;
		  	 }
		  #}
	}
	print "get_pdxc_instance completd\n";
	return \@pdxc_instance;
}

##PDXC Sub routines
sub read_pdxc_config {
	use YAML::XS 'LoadFile';
	my $cfg = LoadFile("$cfg_dir/oc_pdxc.yaml");
	return $cfg;
}

sub pdxc_get_md5 {
        my ($file) = @_;
        my $md5_str;
        if (-f "$file") {
                $md5_str = `$md5_cmd $file`;
                chomp($md5_str);
        } else {
                $md5_str=0;
        }
        $md5_str =~ s/$file//;
        $md5_str =~ s/\s*$//;
        return $md5_str;
}


sub pdxc_s3_md5 {
	my ($cache_file,$source,$bucket,$profile) = @_;
	my ($s3_bucket,$folder);
	$bucket =~ s/s3\:\/\///;
	($s3_bucket=$bucket) =~ s/^(.*?)\/(.*?)$/$1/;
	($folder=$bucket) =~ s/^(.*?)\/(.*?)$/$2/;
	$folder =~ s/\/$//;
	my $cmd = "$aws s3api list-objects-v2 --bucket $s3_bucket --prefix \'$folder/$cache_file\' --profile $profile --output text --query " . '"Contents[].{ETAG: ETag}"';
	my @x = `$cmd`;
	chomp($x[0]);
	$x[0] =~ s/\"//g;
	return $x[0];
}

sub pdxc_s3_deploy_cache {
	my ($cache_file,$source,$bucket,$profile) = @_;
	my $md5 = pdxc_get_md5("$source/$cache_file");
	my $s3_md5 = pdxc_s3_md5($cache_file,$source,$bucket,$profile);
	my $cmd = "$aws s3 cp $source/$cache_file $bucket --profile $profile --sse AES256";
	if ($md5 !~ /$s3_md5/) {
		my $out = system("$cmd");
	} else {
		print "Same version found:$source/$cache_file ($md5 ---- $s3_md5)\n";
	}
}

sub pdxc_s3_getObjectList {
        my ($bucket,$profile) = @_;
        my ($s3_bucket,$folder);
        $bucket =~ s/s3\:\/\///;
        ($s3_bucket=$bucket) =~ s/^(.*?)\/(.*?)$/$1/;
        ($folder=$bucket) =~ s/^(.*?)\/(.*?)$/$2/;
        $folder =~ s/\/$//;
        my $cmd = "$aws s3api list-objects-v2 --bucket $s3_bucket --prefix \'$folder\' --profile $profile --output text --query " . '"Contents[].{Key: Key}"';
        my @x = `$cmd`;
        return \@x;
}

sub pdxc_s3_download_cache {
        my ($cache_file,$dest,$bucket,$profile) = @_;
        $bucket =~ s/\/$//;
        my $md5 = pdxc_get_md5("$dest/$cache_file");
        my $s3_md5 = pdxc_s3_md5($cache_file,$dest,$bucket,$profile);
        my $cmd = "$aws s3 cp $bucket/$cache_file $dest/ --profile $profile --sse AES256";
        if ($md5 !~ /$s3_md5/) {
                my $out = system("$cmd");
        } else {
                print "Same version found:$dest/$cache_file ($md5 ---- $s3_md5)\n";
        }
}

sub suffix_big_nums {
	my ($num) = @_;
	my @suffixes = ('K','M','B','T');
	my $counter = -1;
	my $new_num;
    return $num if $num < 1000;
	while ($num > 1000){
		$counter++;
		$num = $num / 1000;
		$new_num = sprintf("%.0f", $num);
	}
	my $string = $new_num.$suffixes[$counter];
	return $string;
}

sub get_tile_name {
    my ($tile_id) = @_;
    my $metadata_file = "/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/cache/l1_cache/metadata/cache.l1_".$tile_id."_metadata";
    my $tile_metadata = load_cache_byFile($metadata_file);
    return $tile_metadata->{'data-title'};
}

sub aggregations {
	my ($customer) = @_;
	my @list = ('account_reg');
	my %cache = load_cache(\@list);
	my %account_reg = %{$cache{account_reg}};

	my %aggregations = (
						'region' => $account_reg{$customer}{oc_region},													#Scalar
						#'onerun_leader' => $account_reg{$customer}{oc_onerun_leader},   				#Array
						#'mh_region_subregion' => $account_reg{$customer}{mh_region_subregion},	#Array
						#'idm_hub' => $account_reg{$customer}{idm_cluster_hub},									#Array -> This field represents the hub
						'idm_service_line' => $account_reg{$customer}{idm_cluster} ,       			#Array -> This field now represents the Service Line
						'adhoc' => $account_reg{$customer}{adhoc_grouping}      								#Array
						);
	return %aggregations
}


1;
