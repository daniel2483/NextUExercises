#!/usr/bin/perl
## Last Update: 16-Jan-2018 - Srini Rao Pandalaneni: Replaced LWP::Protocl with WWW::Curl

use strict;
use WWW::Curl::Easy;
use HTTP::Request::Common;
use HTTP::Response qw();
use XML::Simple;
use lib '/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/modules';
use lib '/opt/cloudhost/apache/www/cgi-bin/GTOD_CC/modules/pm';

use JSON;
use Data::Dumper;
use FileHandle;
my $domain = 'imbavion.bgr.hp.com:1939';
my $ua;

use CommonHTML;
use LoadCache;
use CommonFunctions;
use POSIX qw(strftime);


#Global Vars
my %rtop;
my %rtop_summary;
my %all_ref;
my %by_customer;

use vars qw($cache_dir);
use vars qw($rawdata_dir);
my ($in,$str,$hashref);

########Load Data From Cache Files############
my @list = ('account_reg');
my %cache = load_cache(\@list);
my %account_reg = %{$cache{account_reg}};
my $start_year = POSIX::strftime("%Y", localtime time);
my $end_date = POSIX::strftime("%Y-%m-%d", localtime time);
my $three_days_ago = POSIX::strftime("%Y-%m-%d", localtime(time-86400*3));
my $start_dt = "$start_year-01-01";

#$ua->proxy('http', "http://www-proxy.omcapj.adapps.hp.com:8080");
#$ua->timeout(30);
my $all_ref;
my %test;
my %ENOTE;

$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME}=0;

#my $endpoint = "https://aenotelbp.syd.omc.hp.com/DataSync/RtopWebServices.asmx";
my $endpoint = "https://aenotelbp.ssn.entsvcs.com/DataSync/RtopWebServices.asmx";
#my $endpoint = "https://aenotelbp.ssn.entsvcs.com/DataSync/RtopWebServices.asmx";

#our $domain = 'menotelb.ssn.entsvcs.com:443'; # AMS Staging Load Balancer
our $domain = 'aenotelbp.ssn.entsvcs.com:443'; #Load Balance Server - We should  connect to this
#our $domain = 'aenotepv03.resrc.entsvcs.com:443'; #Primary
#our $domain = 'aenotepv04.resrc.entsvcs.com:443'; #Secondary

my $cfg = read_config();

my $username = $cfg->{SHAREPOINT_USER};
my $password = $cfg->{SHAREPOINT_PASSWORD};



my $schema;


sub getRtops_ENOTE_curl {

		# Get Rtop Incident From Date
		print "Querying ENOTE webservice using curl.....\n";
		my $message = '<?xml version="1.0" encoding="utf-8"?>
						<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
		  			<soap:Body>
		    			<GetRtopIncidentsFromDate xmlns="https://enotertop.dxc.com/Datasync">
		      		<fromDateString>'."$start_dt".'</fromDateString>
		    			</GetRtopIncidentsFromDate>
		  			</soap:Body>
					</soap:Envelope>';

		my $xml_data;

		my $curl = WWW::Curl::Easy->new;
		$curl->setopt(CURLOPT_HEADER,1);
		$curl->setopt(CURLOPT_SSL_VERIFYPEER,0);
    $curl->setopt(CURLOPT_URL, $endpoint);
    $curl->setopt(CURLOPT_HTTPHEADER, ["Content-Type: text/xml;charset=UTF-8"]);
    $curl->setopt(CURLOPT_POST, 1);
    $curl->setopt(CURLOPT_POSTFIELDS, $message);

    my $response;
    $curl->setopt(CURLOPT_WRITEDATA, \$response);

    my $retcode = $curl->perform;

    if (0 == $retcode) {
        $response = HTTP::Response->parse($response);
        $xml_data = $response->decoded_content;
    } else {
        die sprintf 'libcurl error %d (%s): %s', $retcode, $curl->strerror($retcode), $curl->errbuf;
    }

		#my $xml_data = $response->decoded_content;
		my $xml = new XML::Simple;
		my $count = 0;

		$xml_data =~ s/^.*?(\<rtop_incident\>)/$1/;

		#$xml_data =~ s/[:ascii:]*//g;
		#$xml_data =~ s/[^[:ascii:]]//g;
		$xml_data =~ tr/\cM//d;
		#$xml_data =~ s/[^[a-z|A-Z|0-9|<>\/]]//g;
		$xml_data =~ s/([^\s!\#\$&%\'-;=?-~<>])//g;
		$xml_data =~ s/\&\#xB\;//g;

		#print "FROM ENOTE:    ". $xml_data ;
		# read XML file

		#<rtop_incident><rtop_id>30247</rtop_id><activity_id>59822</activity_id><type_abbrev>IRtOP</type_abbrev><severity_abbrev_long>P2</severity_abbrev_long><status_name>Closed (Completed)</status_name><capability_name>APJ Enterprise Service Mgmt (ESM)</capability_name><svc_interruption_desc>HPSM NWI and SGP unavailable via leased line. Workaround in place.</svc_interruption_desc><client_busi_impact>No current business impact. Workaround applied to all affected clients.</client_busi_impact><users_impacted>100</users_impacted><incident_start>2011-09-15T04:53:00+00:00</incident_start><rtop_start>2011-09-15T07:25:00+00:00</rtop_start><incident_ticket>AU-IM000127959</incident_ticket><contact_firstname>Maria</contact_firstname><contact_lastname>Tourneur</contact_lastname><contact_phone>61290125308</contact_phone><end_dt>2011-09-15T13:52:00+00:00</end_dt><svc_restoration_actions>Services restored to all clients with the exclusion of one, which may have an alternative problem. Investigations continue under separate incident with TPV for remaining issue.</svc_restoration_actions><elapsed_minutes>387</elapsed_minutes><affected_client><related_activity_id>59822</related_activity_id><client_cis_id>1976</client_cis_id><client_erid>12610641</client_erid><client_name>HP ESM</client_name><client_hub_name>US SOUTHWEST (Plano)</client_hub_name><client_hub_abbrev>USSW</client_hub_abbrev><affected_kpe><related_activity_id>59822</related_activity_id><client_cis_id>1976</client_cis_id><eff_kpe_id>124500</eff_kpe_id><kpe_cis_id>6652</kpe_cis_id><kpe_name>HP ESM - ESM APJ SRA Newington</kpe_name></affected_kpe></affected_client><comment><rtop_id>30247</rtop_id><comment_dt>2011-09-15T08:17:12.283+00:00</comment_dt><comment_text>[new record]</comment_text></comment><comment><rtop_id>30247</rtop_id><comment_dt>2011-09-15T14:56:25.42+00:00</comment_dt><comment_text>[record closed - details in Service Restoration Actions field]</comment_text></comment>';

		my @rtops = split(/\<\/rtop_incident>/, $xml_data);

		print "Found ". (scalar(@rtops) - 1). " rtops\n";


		foreach my $rtop_str (@rtops) {
			$rtop_str .= '</rtop_incident>';
			print "#" x 20 . "\n";
			print "XML = $rtop_str\n";

			my $xml = new XML::Simple;

			eval {
				my $rtop = $xml->XMLin($rtop_str,  ForceArray => 1 );

				#print Dumper($rtop);
				#print "#" x 20 . "\n";

				my ($company, $region);
				#Rtops may be associated with more than one client
				foreach my $affected_client (@{$rtop->{affected_client}}) {
					#$company .= $affected_client->{affected_kpe}->[0]->{kpe_name}->[0].",";
					$company .= $affected_client->{client_name}->[0]. "~";
					$region .= $affected_client->{client_hub_name}->[0]."~";
				}

				chop($company);
				chop($region);
				#print Dumper($rtop);
				$rtop_summary{$rtop->{rtop_id}->[0]}{COMPANY} = $company;
				$rtop_summary{$rtop->{rtop_id}->[0]}{REGION} = $region;

				$rtop_summary{$rtop->{rtop_id}->[0]}{STATUS} = $rtop->{status_name}->[0];
				$rtop_summary{$rtop->{rtop_id}->[0]}{START_DT} = $rtop->{rtop_start}->[0];
				$rtop_summary{$rtop->{rtop_id}->[0]}{SEVERITY} = $rtop->{severity_abbrev_long}->[0];
				$rtop_summary{$rtop->{rtop_id}->[0]}{CAPABILITY} = $rtop->{capability_name}->[0];
				$rtop_summary{$rtop->{rtop_id}->[0]}{TYPE} = $rtop->{type_abbrev}->[0];
				$rtop_summary{$rtop->{rtop_id}->[0]}{DESC} = $rtop->{svc_interruption_desc}->[0];
				$rtop_summary{$rtop->{rtop_id}->[0]}{ELAPSED_MINUTES} = $rtop->{elapsed_minutes}->[0];
				$rtop_summary{$rtop->{rtop_id}->[0]}{AFFECTED_SITE} = $rtop->{affected_site_busi_unit}->[0];
				$rtop_summary{$rtop->{rtop_id}->[0]}{USERS_IMPACTED} = $rtop->{users_impacted}->[0];
				$rtop_summary{$rtop->{rtop_id}->[0]}{TICKET} = $rtop->{incident_ticket}->[0];
				$rtop_summary{$rtop->{rtop_id}->[0]}{CONTACT_NAME} = $rtop->{contact_firstname}->[0];
				$rtop_summary{$rtop->{rtop_id}->[0]}{CONTACT_LASTNAME} = $rtop->{contact_lastname}->[0];
				$rtop_summary{$rtop->{rtop_id}->[0]}{CONTACT_PHONE} = $rtop->{contact_phone}->[0];
				$rtop_summary{$rtop->{rtop_id}->[0]}{INC_START} = $rtop->{incident_start}->[0];
				$rtop_summary{$rtop->{rtop_id}->[0]}{REST_ACTIONS} = $rtop->{svc_restoration_actions}->[0];
				$count++;
				print "$count) RTOP ID : $rtop->{rtop_id}->[0]\n";

			};

		}

		print "parsed $count rtops\n";

}

sub getRtops_ENOTE {

		# Get Rtop Incident From Date
		print "Querying ENOTE webservice.....\n";

		my $message = '<?xml version="1.0" encoding="utf-8"?>
						<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
		  			<soap:Body>
		    			<GetRtopIncidentsFromDate xmlns="https://enotertop.dxc.com/Datasync">
		      		<fromDateString>'."$start_dt".'</fromDateString>
		    			</GetRtopIncidentsFromDate>
		  			</soap:Body>
					</soap:Envelope>';


		my @ua_args = (keep_alive => 1);
		my @credentials = ($domain, "", $username, $password);
		my %ssl_options = (SSL_version => 'SSLv3');
		my $schema = LWP::UserAgent->new(ssl_opts => \%ssl_options);
		$schema->credentials(@credentials);
		my $request = HTTP::Request->new(POST => $endpoint);
		$request->header(SOAPAction => 'https://enotertop.dxc.com/Datasync/GetRtopIncidentsFromDate');
		$request->content($message);
		$request->content_type("text/xml; charset=utf-8");
		my $response = $schema->request($request);

		my $xml_data = $response->decoded_content;
		my $xml = new XML::Simple;
		my $count = 0;

		$xml_data =~ s/^.*?(\<rtop_incident\>)/$1/;

		#$xml_data =~ s/[:ascii:]*//g;
		#$xml_data =~ s/[^[:ascii:]]//g;
		$xml_data =~ tr/\cM//d;
		#$xml_data =~ s/[^[a-z|A-Z|0-9|<>\/]]//g;
		$xml_data =~ s/([^\s!\#\$&%\'-;=?-~<>])//g;
		$xml_data =~ s/\&\#xB\;//g;

		#print "FROM ENOTE:    ". $xml_data ;
		# read XML file

		#<rtop_incident><rtop_id>30247</rtop_id><activity_id>59822</activity_id><type_abbrev>IRtOP</type_abbrev><severity_abbrev_long>P2</severity_abbrev_long><status_name>Closed (Completed)</status_name><capability_name>APJ Enterprise Service Mgmt (ESM)</capability_name><svc_interruption_desc>HPSM NWI and SGP unavailable via leased line. Workaround in place.</svc_interruption_desc><client_busi_impact>No current business impact. Workaround applied to all affected clients.</client_busi_impact><users_impacted>100</users_impacted><incident_start>2011-09-15T04:53:00+00:00</incident_start><rtop_start>2011-09-15T07:25:00+00:00</rtop_start><incident_ticket>AU-IM000127959</incident_ticket><contact_firstname>Maria</contact_firstname><contact_lastname>Tourneur</contact_lastname><contact_phone>61290125308</contact_phone><end_dt>2011-09-15T13:52:00+00:00</end_dt><svc_restoration_actions>Services restored to all clients with the exclusion of one, which may have an alternative problem. Investigations continue under separate incident with TPV for remaining issue.</svc_restoration_actions><elapsed_minutes>387</elapsed_minutes><affected_client><related_activity_id>59822</related_activity_id><client_cis_id>1976</client_cis_id><client_erid>12610641</client_erid><client_name>HP ESM</client_name><client_hub_name>US SOUTHWEST (Plano)</client_hub_name><client_hub_abbrev>USSW</client_hub_abbrev><affected_kpe><related_activity_id>59822</related_activity_id><client_cis_id>1976</client_cis_id><eff_kpe_id>124500</eff_kpe_id><kpe_cis_id>6652</kpe_cis_id><kpe_name>HP ESM - ESM APJ SRA Newington</kpe_name></affected_kpe></affected_client><comment><rtop_id>30247</rtop_id><comment_dt>2011-09-15T08:17:12.283+00:00</comment_dt><comment_text>[new record]</comment_text></comment><comment><rtop_id>30247</rtop_id><comment_dt>2011-09-15T14:56:25.42+00:00</comment_dt><comment_text>[record closed - details in Service Restoration Actions field]</comment_text></comment>';

		my @rtops = split(/\<\/rtop_incident>/, $xml_data);

		print "Found ". (scalar(@rtops) - 1). " rtops\n";


		foreach my $rtop_str (@rtops) {
			$rtop_str .= '</rtop_incident>';
			print "#" x 20 . "\n";
			print "XML = $rtop_str\n";

			my $xml = new XML::Simple;

			eval {
				my $rtop = $xml->XMLin($rtop_str,  ForceArray => 1 );

				#print Dumper($rtop);
				#print "#" x 20 . "\n";

				my ($company, $region);
				#Rtops may be associated with more than one client
				foreach my $affected_client (@{$rtop->{affected_client}}) {
					#$company .= $affected_client->{affected_kpe}->[0]->{kpe_name}->[0].",";
					$company .= $affected_client->{client_name}->[0]. "~";
					$region .= $affected_client->{client_hub_name}->[0]."~";
				}

				chop($company);
				chop($region);
				#print Dumper($rtop);
				$rtop_summary{$rtop->{rtop_id}->[0]}{COMPANY} = $company;
				$rtop_summary{$rtop->{rtop_id}->[0]}{REGION} = $region;

				$rtop_summary{$rtop->{rtop_id}->[0]}{STATUS} = $rtop->{status_name}->[0];
				$rtop_summary{$rtop->{rtop_id}->[0]}{START_DT} = $rtop->{rtop_start}->[0];
				$rtop_summary{$rtop->{rtop_id}->[0]}{SEVERITY} = $rtop->{severity_abbrev_long}->[0];
				$rtop_summary{$rtop->{rtop_id}->[0]}{CAPABILITY} = $rtop->{capability_name}->[0];
				$rtop_summary{$rtop->{rtop_id}->[0]}{TYPE} = $rtop->{type_abbrev}->[0];
				$rtop_summary{$rtop->{rtop_id}->[0]}{DESC} = $rtop->{svc_interruption_desc}->[0];
				$rtop_summary{$rtop->{rtop_id}->[0]}{ELAPSED_MINUTES} = $rtop->{elapsed_minutes}->[0];
				$rtop_summary{$rtop->{rtop_id}->[0]}{END_DT} = $rtop->{end_dt}->[0];
				$rtop_summary{$rtop->{rtop_id}->[0]}{AFFECTED_SITE} = $rtop->{affected_site_busi_unit}->[0];
				$rtop_summary{$rtop->{rtop_id}->[0]}{USERS_IMPACTED} = $rtop->{users_impacted}->[0];
				$rtop_summary{$rtop->{rtop_id}->[0]}{TICKET} = $rtop->{incident_ticket}->[0];
				$rtop_summary{$rtop->{rtop_id}->[0]}{CONTACT_NAME} = $rtop->{contact_firstname}->[0];
				$rtop_summary{$rtop->{rtop_id}->[0]}{CONTACT_LASTNAME} = $rtop->{contact_lastname}->[0];
				$rtop_summary{$rtop->{rtop_id}->[0]}{CONTACT_PHONE} = $rtop->{contact_phone}->[0];
				$rtop_summary{$rtop->{rtop_id}->[0]}{INC_START} = $rtop->{incident_start}->[0];
				$rtop_summary{$rtop->{rtop_id}->[0]}{REST_ACTIONS} = $rtop->{svc_restoration_actions}->[0];
				$count++;
				print "$count) RTOP ID : $rtop->{rtop_id}->[0]\n";

			};

		}

		print "parsed $count rtops\n";

}

sub processRTOPS
{

	my ($rtop_customer,$customer,$id,$pri,$status,$cap,$owner,$impact,$open_dt,$close_dt,$desc,$rtop_type);


	foreach my $rtop_id (sort keys %rtop_summary) {

			#next if ($rtop_summary{$rtop_id}{REGION} !~ /$cfg->{RTOP_SUBREGION_NAME}/i);
			if (not defined($rtop{$rtop_id})) {
				$customer="";
				my @x="";
				my $uct_time=time();

				my $rtop_client;
				# We might have multiple customers here - so find the first one
				foreach my $c (split(/~/,$rtop_summary{$rtop_id}{COMPANY})) {

					#@x = split(/-/,$c);
					#$x[0] =~ s/^\s*//g;
					#$x[0] =~ s/\s*$//g;
					#$x[0] =~ s/\)$//g;
					$c=~s/\s*$//g;
					$c=~s/^\s*//g;

					$customer = map_customer_to_sp(\%account_reg,$c,"","ANY");
					$rtop_client = $c;
					last if ($customer !~ /not_mapped/i);
			  }

			  $customer=lc($customer);
			  #print "New One found ($rtop_id) (created: $rtop_summary{$rtop_id}{START_DT}): (status: $rtop_summary{$rtop_id}{STATUS}) ----------, $rtop_client,$customer\n";
				$rtop{$rtop_id}{CUSTOMER} = $customer;
				$rtop{$rtop_id}{STATUS} = $rtop_summary{$rtop_id}{STATUS};
				$rtop{$rtop_id}{PRI} = $rtop_summary{$rtop_id}{SEVERITY};
				$rtop{$rtop_id}{CAP} = $rtop_summary{$rtop_id}{CAPABILITY};
				$rtop{$rtop_id}{OWNER} = "";
				$rtop{$rtop_id}{IMPACT} = $rtop_summary{$rtop_id}{DESC};
				$rtop{$rtop_id}{OPENDT} = $rtop_summary{$rtop_id}{START_DT};
				$rtop{$rtop_id}{DESC} = $rtop_summary{$rtop_id}{DESC};
				$rtop{$rtop_id}{RTOP_CUSTOMER} = $rtop_client;
				$rtop{$rtop_id}{RTOP_TYPE} = $rtop_summary{$rtop_id}{TYPE};
				$rtop{$rtop_id}{END_DT} = $rtop_summary{$rtop_id}{END_DT};
				$rtop{$rtop_id}{AFFECTED_SITE} = $rtop_summary{$rtop_id}{AFFECTED_SITE};
				$rtop{$rtop_id}{IMPACTED_USERS} = $rtop_summary{$rtop_id}{USERS_IMPACTED};
				$rtop{$rtop_id}{TICKET} = $rtop_summary{$rtop_id}{TICKET};
				$rtop{$rtop_id}{CONTACT_NAME} = $rtop_summary{$rtop_id}{CONTACT_NAME};
				$rtop{$rtop_id}{CONTACT_LASTNAME} = $rtop_summary{$rtop_id}{CONTACT_LASTNAME};
				$rtop{$rtop_id}{CONTACT_PHONE} = $rtop_summary{$rtop_id}{CONTACT_PHONE};
				$rtop{$rtop_id}{INC_START} = $rtop_summary{$rtop_id}{INC_START};
				$rtop{$rtop_id}{REST_ACTIONS} = $rtop_summary{$rtop_id}{REST_ACTIONS};

				###Convert start date to epoch
				my $rtop_start_tick=0;
				#if ($rtop_summary{$rtop_id}{START_DT} =~ /^(.*?)T(.*?)\+(.*?)$/) {
				#09/06/2018 10:15:00
				if ($rtop_summary{$rtop_id}{START_DT} =~ /^(\d{2})\/(\d{2})\/(\d{4})\s+(\d{2})\:(\d{2})\:(\d{2})$/) {
						#my $dt_str = $1;
						#my $time_str = $2;
						#my @dt_value = split(/-/,$dt_str);
						#my @time_value = split(/:/,$time_str);

						# $6 = seconds
						# $5 = minutes
						# $4 = hours
						# $3 = Year
						# $2 = Day
						# $1 = Month
						$rtop_start_tick = POSIX::mktime($6,$5,$4,$2,$1-1,$3-1900);
				}
				$rtop{$rtop_id}{START_TICK} = $rtop_start_tick;
				#print "->>>>>>>>>>>>>>>>>>>>>  RTOP ID = $rtop_id ELAPSED_MINUTES = $rtop_summary{$rtop_id}{ELAPSED_MINUTES} and End Date = $rtop_summary{$rtop_id}{END_DT}\n";

				if ($rtop_summary{$rtop_id}{ELAPSED_MINUTES} =~ /^\d+$/) {
					if ($rtop_summary{$rtop_id}{ELAPSED_MINUTES} >59) {
						my $x = sprintf "%0.2f", $rtop_summary{$rtop_id}{ELAPSED_MINUTES}/60;
						my @val = split(/\./,$x);
						if ($val[0] > 23) {
							$rtop{$rtop_id}{ELAPSED_MINUTES} = sprintf "%0.1f days", $x /24;
						} else {
							$rtop{$rtop_id}{ELAPSED_MINUTES} = "$val[0] hour[s] ";
							if ($val[1] > 0) {
								$rtop{$rtop_id}{ELAPSED_MINUTES} .= sprintf "%d mins", ($val[1] * 60) / 100;
							}
						}
					} else {
						$rtop{$rtop_id}{ELAPSED_MINUTES} = $rtop_summary{$rtop_id}{ELAPSED_MINUTES} . " mins";
					}
				} elsif ($rtop_summary{$rtop_id}{END_DT} =~ /^(.*?)T(.*?)\+(.*?)$/) {
					my $dt_str = $1;
					my $time_str = $2;
					my @dt_value = split(/-/,$dt_str);
					my @time_value = split(/:/,$time_str);
					my $rtop_end_tick = POSIX::mktime($time_value[2],$time_value[1],$time_value[0],$dt_value[2],$dt_value[1]-1,$dt_value[0]-1900);

					if ($rtop_start_tick > 0 and $rtop_end_tick > 0) {
						my $x = sprintf "%0.2f", ($rtop_end_tick - $rtop_start_tick) / 3600;
						my @val = split(/\./,$x);
						if ($val[0] > 23) {
							$rtop{$rtop_id}{ELAPSED_MINUTES} = sprintf "%0.1f days", $x /24;
						} else {
							$rtop{$rtop_id}{ELAPSED_MINUTES} = "$val[0] hour[s] ";
							if ($val[1] > 0) {
								$rtop{$rtop_id}{ELAPSED_MINUTES} .= sprintf "%d mins", ($val[1] * 60) / 100;
							}
						}
					}
					#
				} elsif ($rtop_summary{$rtop_id}{STATUS} !~ /resolved|closed/i) {
					my $x = sprintf "%0.2f", ($uct_time - $rtop_start_tick) / 3600; # Converting to hours
					#print "CLOSED OR RESOLVED MIUTES, (status: $rtop_summary{$rtop_id}{STATUS}), RTOP = $rtop_id = $x (Current Time = $uct_time minus RTOP START = $rtop_start_tick  START_DT=$rtop_summary{$rtop_id}{START_DT}\n";
					#exit;
					my @val = split(/\./,$x);
					if ($val[0] > 23) {
							my $y = $rtop{$rtop_id}{ELAPSED_MINUTES} = sprintf "%0.1f days", $x /24; # Get days
							#print "CLOSED OR RESOLVED DAYS, (status: $rtop_summary{$rtop_id}{STATUS}), RTOP = $rtop_id = $y (Current Time = $uct_time minus RTOP START = $rtop_start_tick  START_DT=$rtop_summary{$rtop_id}{START_DT}\n";
							#exit;
						} else {
							$rtop{$rtop_id}{ELAPSED_MINUTES} = "$val[0] hour[s] "; # Get hours
							if ($val[1] > 0) {
								my $z = $rtop{$rtop_id}{ELAPSED_MINUTES} .= sprintf "%d mins", ($val[1] * 60) / 100;
								#print "CLOSED OR RESOLVED DAYS, (status: $rtop_summary{$rtop_id}{STATUS}), RTOP = $rtop_id = $z (Current Time = $uct_time minus RTOP START = $rtop_start_tick  START_DT=$rtop_summary{$rtop_id}{START_DT}\n";
								#exit;
							}
						}
				}

		  }
		}

		##
		foreach my $row (values %$all_ref) {
			foreach my $ln (@$row) {
				print Dumper($ln);
				#next if ($ln->{Region} !~ /$cfg->{RTOP_REGION_NAME}/i);
				$customer="";
				$id="";
				$owner="";
				$status="";
				$cap="";
				$impact="";
				$open_dt="";
				$pri="";
				$desc="";
				$rtop_type="";
				$rtop_customer = lc($ln->{AffectedClient});
				$id = $ln->{RtopId};
				$pri = $ln->{Priority};
				$status = $ln->{IncidentStatus};
				$owner= $ln->{IncidentOwner};
				$cap = $ln->{RcaOwnerCapability};
				$impact = $ln->{ClientImpact};
				$open_dt = $ln->{ReportDate};
				$desc = $ln->{IncidentTitle};
				$rtop_customer =~ s/\"//g;
				$rtop_type = $ln->{RtopType};
				$customer = map_customer_to_sp(\%account_reg,$rtop_customer,"","ANY");
				$customer=lc($customer);
				if ($customer =~ /not_mapped/i) { $test{$rtop_customer}="$customer"; }
				if ($cap =~ /Wintel/i) { $cap="Wintel"; }
				if ($cap =~ /UNIX/i) { $cap="Midrange"; }
				if ($cap =~ /Software/i) { $cap="Database"; }
				if ($cap =~ /Storage/i) { $cap="Storage"; }
				if ($cap !~ /Midrange|software|storage|backup/i) { $cap="other"; }
				$rtop{$id}{CUSTOMER} = $customer;
				$rtop{$id}{STATUS} = $status;
				$rtop{$id}{PRI} = $pri;
				$rtop{$id}{CAP} = $cap;
				$rtop{$id}{OWNER} = $owner;
				$rtop{$id}{IMPACT} = $impact;
				$rtop{$id}{OPENDT} = $open_dt;
				$rtop{$id}{DESC} = $desc;
				$rtop{$id}{RTOP_CUSTOMER} = $rtop_customer;
				$rtop{$id}{RTOP_TYPE} = $rtop_type;


			}

		}

}

sub getRtops {

	print "Querying imbavion.bgr.hp.com webservice.....\n";
	my $rtops_url='http://imbavion.bgr.hp.com:1939/api/RtopsList?PeriodMode=ReportDate&' . "FromDate\=$start_year-01-01" . "\&ToDate\=$end_date";
	print "URL = $rtops_url\n";
	my $res = $ua->request(GET $rtops_url);
	print $rtops_url . "\n";
	#print $res->decoded_content;
	my $json = JSON->new->allow_nonref;
	#eval { $all_ref = $json->pretty->decode($res->decoded_content); };

	print "RES = ". $res->decoded_content;

	$all_ref = JSON->new->utf8->decode($res->decoded_content);

}

## Added to allow for filtering the cache data by Customer and region for use with the oc_api.pl
sub by_customer {
	foreach my $id (keys %rtop){

		$by_customer{$rtop{$id}{CUSTOMER}}{$id}= $rtop{$id};
	}
}
#####Main###

print "Year to Query is : $start_year\n";



#getRtops();
#getRtops_ENOTE();
getRtops_ENOTE_curl();
#print Dumper(\%$all_ref);
processRTOPS();
by_customer();
save_hash("cache.rtops_all",\%rtop);
save_hash("cache.rtops_by_customer",\%by_customer);
