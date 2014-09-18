#!/usr/bin/perl -w

# check_cisco_fru_ps Nagios Plugin
#
# TComm - Oscar Navalon Claramunt
# Checks the operational state of the powers on a 
# CISCO-ENTITY-FRU-CONTROL-MIB  complaint device
#
# This nagios plugin is free software, and comes with ABSOLUTELY 
# NO WARRANTY. It may be used, redistributed and/or modified under 
# the terms of the GNU General Public Licence (see 
# http://www.fsf.org/licensing/licenses/gpl.txt).


# MODULE DECLARATION

use strict;

use lib "/usr/local/nagios/perl/lib/";

use Nagios::Plugin;
use Net::SNMP qw(SNMP_VERSION_2C);



# FUNCTION DECLARATION

sub CreateNagiosManager ();
sub CheckArguments ();
#sub PerformCheck ();


# CONSTANT DEFINITION

use constant cefcFRUPowerOperStatus => '1.3.6.1.4.1.9.9.117.1.1.2.1.2';
use constant entPhysicalDescr =>'1.3.6.1.2.1.47.1.1.1.1.2';

use constant MODE_TEST => 1;
use constant MODE_CHECK => 2;
use constant NAME => 	'check_cisco_fru_ps';
use constant VERSION => '0.1b';
use constant USAGE => 	"Usage:\ncheck_cisco_fru_ps -H <hostname> [-e <power id list>] [-w <warning list> -c <critical list>]\n".
								"\t\t[-C <SNMP Community>]  [E <SNMP Version>] [-P <SNMP port>]\n".
								"\t\t[-V <version>]\n";
use constant BLURB => 	"This plugin checks the operational state of the powers\n".
								"on a CISCO-ENTITY-FRU-CONTROL-MIB complaint device.";
use constant LICENSE => "This nagios plugin is free software, and comes with ABSOLUTELY\n".
								"no WARRANTY. It may be used, redistributed and/or modified under\n".
								"the terms of the GNU General Public Licence\n".
								"(see http://www.fsf.org/licensing/licenses/gpl.txt).\n";
use constant EXAMPLE => "\n\n".
					"Example:\n".
					"\n".
					"check_cisco_fru_ps -H 192.168.0.13\n".
					"\n".
					"Test Mode that checks the compatibility of the plugin on a host with address 192.168.0.13\n".
					"using SNMP protocol version 1 and 'public' as community\n".
					"Plugin returns OK if it is a CISCO-ENTITY-FRU-CONTROL-MIB compliant device and can recover powers data. Also, a list of all powers\n".
					"with id, status and description is returned. If it is not compatible returns UNKNOWN\n".
					"\n".
					"check_cisco_fru_ps -H 192.168.0.13 -e 120,121 -w 9,12 -c 8\n".
					"\n".
					"Checks, on a CISCO-ENTITY-FRU-CONTROL-MIB compliant device with IP address 192.168.0.13,\n".								
					"if any of the powers passed through their id with the -e argument\n".
					"are in any of the states passed in -w and -c argument.\n". 	
					"It returns CRITICAL if any power (120 or 121 power id) has a state with id 8, \n" .
					"WARNING if any power has a state with id 9 or 12, and in other case returns OK\n" .
					"The operational FRU power state is:\n".
						"\t1:offEnvOther\n".
						"\t2:on\n".
						"\t3:offAdmin\n".
						"\t4:offDenied\n".
						"\t5:offEnvPower\n".
						"\t6:offEnvTemp\n".
						"\t7:offEnvFan\n".
						"\t8:failed\n".
						"\t9:onButFanFail\n".
						"\t10:offCooling\n".
						"\t11:offConnectorRating\n".
						"\t12:onButInlinePowerFail";


								
# VARIABLE DEFINITION

my $Nagios;
my $Error;
my $PluginMode;
my $PluginReturnValue, my $PluginOutput="";


# MAIN FUNCTION

# Get command line arguments
$Nagios = &CreateNagiosManager(USAGE, VERSION, BLURB, LICENSE, NAME, EXAMPLE);
eval {$Nagios->getopts};

if (!$@) {
	# Command line parsed
	if (&CheckArguments($Nagios, $Error, $PluginMode)) {
		# Argument checking passed

		if ($PluginMode == MODE_TEST) {
			$PluginReturnValue = &TestHost($Nagios, $PluginOutput);
			$PluginOutput = "TEST MODE\n\n" . $PluginOutput;
		}
		else {
			$PluginReturnValue = &PerformCheck($Nagios, $PluginOutput)
		}
		
	}
	else {
		# Error checking arguments
		$PluginOutput = $Error;
		$PluginReturnValue = UNKNOWN;
	}
	$Nagios->nagios_exit($PluginReturnValue,$PluginOutput);
}
else {
	# Error parsing command line
	$Nagios->nagios_exit(UNKNOWN,$@);
}
		
	
# FUNCTION DEFINITIONS

# Creates and configures a Nagios plugin object
# Input: strings (usage, version, blurb, license, name and example) to configure argument parsing functionality
# Return value: reference to a Nagios plugin object

sub CreateNagiosManager() {
	# Create GetOpt object
	my $Nagios = Nagios::Plugin->new(usage => $_[0], version =>  $_[1], blurb =>  $_[2], license =>  $_[3], plugin =>  $_[4], extra =>  $_[5]);
	
	# Add argument hostname
	$Nagios->add_arg(spec => 'hostname|H=s',
				help => 'SNMP agent hostname or IP address',
				required => 1);				
					
	# Add argument community
	$Nagios->add_arg(spec => 'community|C=s',
				help => 'SNMP agent community (default: public)',
				default => 'public',
				required => 0);				
	# Add argument version
	$Nagios->add_arg(spec => 'snmpver|E=s',
				help => 'SNMP protocol version (default: 2)',
				default => '2',
				required => 0);				
	# Add argument port
	$Nagios->add_arg(spec => 'port|P=i',
				help => 'SNMP agent port (default: 161)',
				default => 161,
				required => 0);
	
	# Add argument ids
	$Nagios->add_arg(spec => 'ids|e=s',
				help => "Power id list <idPower>(,<idPower>)*",
				required => 0);
	# Add argument warning
	$Nagios->add_arg(spec => 'warning|w=s',
				help => "Warning thresholds in the format <idPowerState>(,<idPowerState>)*",
				required => 0);
	# Add argument critical
	$Nagios->add_arg(spec => 'critical|c=s',
				help => "Critical threshold in the format <idPowerState>(,<idPowerState>)*",
				required => 0);				
	# Return value
	return $Nagios;
}


# Checks argument values and sets some default values
# Input: Nagios Plugin object
# Output: Error description string
# Return value: True if arguments ok, false if not

sub CheckArguments() {
	my $Nagios = $_[0];
	 my @WarningTypes;
	 my $WarningType;

	 my @CriticalTypes;
	 my $CriticalType;

	if ( $Nagios->opts->port <= 0 ) {
		$_[1] = "Invalid SNMP agent port: must be greater than zero";
		return 0;
	}
	if ((!defined $Nagios->opts->warning) && (!defined $Nagios->opts->critical)){#Test mode
		$_[2] = MODE_TEST;
		return 1;
	}
	elsif((defined $Nagios->opts->warning) && (defined $Nagios->opts->critical)){	
		#Check Warnings Ids
		if ($Nagios->opts->warning =~ /^\d+(,\d+)*$/) { #One or more digits
		  @WarningTypes = split(/,/, $Nagios->opts->warning);
		  foreach $WarningType(@WarningTypes) {
		      if ($WarningType < 0 || $WarningType > 65535) {
			$_[1] = "Invalid warning id state";
			return 0;
		      }
		  }          
		}
		else{
		  $_[1] = "Invalid warning id큦 expression";
		  return 0;
		}
		#Check Critical Id큦
		if ($Nagios->opts->critical =~ /^\d+(,\d+)*$/) { #One or more digits
		  @CriticalTypes = split(/,/, $Nagios->opts->critical);
		  foreach $CriticalType(@CriticalTypes) {
		      if ($CriticalType < 0 || $CriticalType > 65535) {
			$_[1] = "Invalid critical id state";
			return 0;
		      }
		  }          
		}
		else{
		  $_[1] = "Invalid critical id큦 expression";
		  return 0;
		}
		 if ($Nagios->opts->ids !~ /^\d+(,\d+)*$/) {
			 $_[1] = "Invalid power id큦 expression";
			return 0;
		}
		$_[2] = MODE_CHECK;
	}
	else{
		$_[1] = "Invalid arguments.It must be defined critical and warning argument for check mode or neither of both for test mode.";
		return 0;
	}
return 1;
}

# Checks if host supports powers data on CISCO-ENTITY-FRU-CONTROL-MIB .
# If OK, it returns info about powers 
# Input: Nagios Plugin object
# Output: Test output string
# Return value: OK if test passed, UNKNOWN if not.

sub TestHost() {
	my $SNMPSession;
	my $SNMPError;
	my $Output="";
	my $PluginReturnValue;
	my @FruMessages;
	$FruMessages[1]="OffEnvOther";
	$FruMessages[2]="On";
	$FruMessages[3]="OffAdmin";
	$FruMessages[4]="OffDenied";
	$FruMessages[5]="OffEnvPower";
	$FruMessages[6]="OffEnvTemp"; 
	$FruMessages[7]="OffEnvFan"; 
	$FruMessages[8]="Failed";
	$FruMessages[9]="OnButFanFail"; 
	$FruMessages[10]="OffCooling"; 
	$FruMessages[11]="OffConnectorRating"; 
	$FruMessages[12]="OnButInlinePowerFail"; 
	
	($SNMPSession, $SNMPError) = Net::SNMP->session(-hostname => $Nagios->opts->hostname, -community => $Nagios->opts->community, -version => $Nagios->opts->snmpver, -port => $Nagios->opts->port, -timeout => $Nagios->opts->timeout);
	
	if (defined($SNMPSession)) {
		my $RequestResultIndex = $SNMPSession->get_entries(-columns => [cefcFRUPowerOperStatus]);
		my $RequestResultDesc=$SNMPSession->get_entries(-columns => [entPhysicalDescr]);
		if (!defined($RequestResultIndex) || !defined($RequestResultDesc)){
			$SNMPSession->close();
			return UNKNOWN;	
		}
		my $id;
		my $Oid;
		my $status;
		my $desc="";
		$Output = "CISCO POWERS DATA\n";
		foreach  $Oid (keys %{$RequestResultIndex}){
			$id = (split(/\./, $Oid))[-1];
			$status = $FruMessages[$RequestResultIndex->{$Oid}];
			$desc = $RequestResultDesc->{entPhysicalDescr.".$id"} if defined $RequestResultDesc->{entPhysicalDescr.".$id"};
			$Output.= "Power id = $id \t\t\t Power status = ".$RequestResultIndex->{$Oid}." ($status) \t\t Power description = $desc \n";
		}
		$PluginReturnValue = OK;
		$SNMPSession->close();
	}
	else {
		$PluginReturnValue = UNKNOWN;
	}		
	$_[1]=$Output;
	
	return $PluginReturnValue;
}


# # Performs whole check: 
# # Input: Nagios Plugin object
# # Output: Plugin output string
# # Return value: Plugin return value

 sub PerformCheck() {

	
 	my $SNMPSession;
 	my $SNMPError;
	my $i;
	my $j;
	#my @descriptionOId;
	my @PowerIds;
	my $PowerId;
	my $PowerValue;
	
	my @CriticalTypes = split(/,/, $Nagios->opts->critical);
	my @WarningTypes = split(/,/, $Nagios->opts->warning);
 	my $CriticalOutput="";
	my $WarningOutput="";
	my @RangeWarningTypes;
  	my @RangeCriticalTypes;
 	my $PluginOutput;
 	my $PluginReturnValue = UNKNOWN;
	
	my @FruMessages;
	my $RequestResult ;
	my $PowerName;
	$FruMessages[1]=  "FRU is powered off because of a problem not listed below."; # offEnvOther(1)
	$FruMessages[2]="FRU is powered on."; # on(2)
	$FruMessages[3]="Administratively off."; # offAdmin(3)
	$FruMessages[4]="FRU is powered off because available system power is insufficient."; # offDenied(4)
	$FruMessages[5]="FRU is powered off because of power problem in the FRU. for example, the FRU's power translation (DC-DC converter) or distribution failed."; #offEnvPower(5)
	$FruMessages[6]="FRU is powered off because of temperature problem."; # offEnvTemp(6) 
	$FruMessages[7]="FRU is powered off because of fan problems.";# offEnvFan(7) 
	$FruMessages[8]="FRU is in failed state. "; # failed(8)
	$FruMessages[9]="FRU is on, but fan has failed."; # onButFanFail(9) 
	$FruMessages[10]="FRU is powered off because of the system's insufficient cooling capacity."; # offCooling(10) 
	$FruMessages[11]="FRU is powered off because of the system's connector rating exceeded."; # offConnectorRating(11) 
	$FruMessages[12]="The FRU on, but no inline power is being delivered as the data/inline power component of the FRU has failed."; # onButInlinePowerFail(12) 
	
	

# 	# Start new SNMP session
 	($SNMPSession, $SNMPError) = Net::SNMP->session(-hostname => $Nagios->opts->hostname, 
 	                                                -community => $Nagios->opts->community, 
 	                                                -version => $Nagios->opts->snmpver, 
 	                                                -port => $Nagios->opts->port);
	
	if (!defined($SNMPSession)) {
		$PluginOutput = "Error '$SNMPError' starting session";
        }
 	else {
		@PowerIds = split(/,/, $Nagios->opts->ids);
		foreach $PowerId(@PowerIds) {
			$RequestResult = $SNMPSession->get_request(-varbindlist => [ cefcFRUPowerOperStatus.".$PowerId"]);
			if (!defined($RequestResult)) {	
				$SNMPSession->close();
				$_[1] = "Not exists power with id =$PowerId";
				return UNKNOWN;
			}
			$PowerValue=$$RequestResult{cefcFRUPowerOperStatus.".$PowerId"};
			if ($PowerValue !~ /^\d+$/){
				$SNMPSession->close();
				$_[1] = "No Such Instance ($PowerId) currently exists at this OID";
				return UNKNOWN;
			}
			$RequestResult=$SNMPSession->get_request(-varbindlist => [ entPhysicalDescr.".$PowerId"]);
			if ((!defined($RequestResult) )|| ($$RequestResult{entPhysicalDescr.".$PowerId"} =~ m/No Such/)){
				$SNMPSession->close();
				$_[1] = "Error recovering power name with id $PowerId";
				return UNKNOWN;
			}
			$PowerName=$$RequestResult{entPhysicalDescr.".$PowerId"};
			for ($j=0; $j <=$#CriticalTypes; $j++) {
				@RangeCriticalTypes=split(/\.\./, $CriticalTypes[$j]);
				if($#RangeCriticalTypes){#Checking range
					if(($PowerValue >= $RangeCriticalTypes[0]) and ($PowerValue <=$RangeCriticalTypes[1])){
						$CriticalOutput .= "Power $PowerName: $FruMessages[$PowerValue]; ";
						last;
					}
				}
				else{
					if ($PowerValue== $RangeCriticalTypes[0] ){
						$CriticalOutput .= "Power $PowerName: $FruMessages[$PowerValue]; ";
						last;
					}
				}
			}
			if ($CriticalOutput eq ''){ #No critical state
				for ($j=0; $j <=$#WarningTypes; $j++) {
					@RangeWarningTypes=split(/\.\./, $WarningTypes[$j]);
					if($#RangeWarningTypes){#Checking range
						if(($PowerValue >= $RangeWarningTypes[0]) and ($PowerValue <=$RangeWarningTypes[1])){
							$WarningOutput .= "Power $PowerName: $FruMessages[$PowerValue]; ";
							last;
						}
					}
					else{
						if ($PowerValue == $RangeWarningTypes[0] ){
							$WarningOutput .= "Power $PowerName: $FruMessages[$PowerValue]; ";
							last;
						}
					}
				}
			}			
			
		}
		
		if ($CriticalOutput ne ''){
			$PluginReturnValue = CRITICAL;
                    	$PluginOutput = $CriticalOutput;
		}
		else{
			if ($WarningOutput ne ''){
				$PluginReturnValue = WARNING;
				$PluginOutput = $WarningOutput;
			}
			else{
		 		$PluginReturnValue = OK;
				$PluginOutput = "All checked powers are OK";
			}
	
		}
             
	$SNMPSession->close();
	}
	
 	#Return result
 	$_[1] = $PluginOutput;
 	return $PluginReturnValue;
 }
