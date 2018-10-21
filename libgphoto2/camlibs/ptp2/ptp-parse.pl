#!/usr/bin/perl
# Copyright Marcus Meissner 2005.
# Licensed under GPL v2. NO WARRANTY.
# 
# This is mostly unfinished ...

use strict;
use XML::Parser;
use IO::Handle;

my $xmlfile = shift @ARGV || die "specify xml file on cmdline:$!\n";

my @elemstack = ();
my @data = 0;
my $needdata = 0;
my $curseq = -1;
my $curep = -1;
my %urbenc = ();
my @curdata = ();
my $lastcode;
my $vendorid = 0;

my $size=-s $xmlfile;
my $buffer;
sysopen(BINFILE,$xmlfile,0) || die "sysopen: $!";
sysread(BINFILE,$buffer,$size);
close(BINFILE);

my @data = unpack("C*",$buffer);
if ($data[0] == 60) { # 60 == '<' ... start of XML file ...
	my $p1 = new XML::Parser(
		 Handlers => {	Start => \&xml_handle_start,
				End   => \&xml_handle_end,
				Char  => \&xml_handle_char}
	);
	$p1->parsefile($xmlfile);
	exit 0;
}

# binary file parser ... Looking for ptp usb traffic 
my $expectseqnr = 0;
my @curdata;
my $dataskip;
my $off = 0;
while ($#data) {
	my $type  = $data[4] | ($data[5] << 8);
	if (($type < 1) || ($type > 4)) {
		$off++;
		shift @data;
		next;
	}
	my $code  = $data[6] | ($data[7] << 8);
	my $len   = $data[0] | ($data[1] << 8) | ($data[2] << 16) | ($data[3] << 24);
	my $seqnr = $data[8] | ($data[9] << 8) | ($data[0xa] << 16) | ($data[0xb] << 24);
	if ($code < 0x1000) { $off++;shift @data; next; }
	if ($seqnr != $expectseqnr) {
		$off++;
		shift @data;
		next;
	}
	if ($len > $#data) {
		$off++;
		shift @data;
		next;
	}
	if ($type == 1) {
		$dataskip = 1;
		$lastcode = $code;
		# $dataskip = 0 if ($code == 0x1008);
		$dataskip = 0 if ($code == 0x9007);
		@curdata = ();
	}
	# printf "off %x, type = %04x, code=%04x, len = %08x, seqnr = %08x\n", $off, $type, $code, $len, $seqnr;
	my @bytes;
	if ($len <= 64) {
 		@bytes = @data[0xc..$len-1];
	} else {
 		@bytes = @data[0xc..0x3f]+@data[0x40+0x120..0x120+$len-1];
	}
	if ($type == 2) {
		if ($dataskip == 0) {
			my $i;
			@curdata = @data[0xc..$len-1];
			if ($len <= 64) {
				@curdata = @data[0xc..$len-1];
			} else {
				@curdata = (@data[0xc..0x3f],@data[0x40+0x120..0x120+$len-1]);
			}
		}
		$dataskip--;
	}
	dump_ptp_line($type,$code,\@bytes,\@curdata);
	if ($type == 3) {
		$expectseqnr++;
		@curdata = ();
	}
	$off++;
	shift @data;
}
print "done\n";
exit 0;


sub hexdump {
	my @data = @_;
	my $i;
	my $str = "";
	for ($i = 0;$i <= $#data ; $i++) {
		my $c = $data[$i];
		if (($i & 0x0f) == 0) {
			if ($i) {
				print " $str\n";
				$str = "";
			}
			printf "%03x: ", $i;
		}
		printf " %02x", $c;
		if (($c >= 0x20) && ($c < 0x7f)) {
			$str .= sprintf "%c", $c;
		} else {
			$str .= ".";
		}
	}
	printf " $str\n";
}

sub get_uint32 {
	my($arrref) = @_;

	return	shift(@{$arrref})+256*(shift(@{$arrref}))+
		256*256*shift(@{$arrref})+256*256*256*(shift(@{$arrref}));
}

sub get_uint16 {
	my($arrref) = @_;

	return shift(@{$arrref})+256*(shift(@{$arrref}));
}

sub get_uint8 {
	my($arrref) = @_;

	return shift @{$arrref};
}

sub get_str {
	my($arrref) = @_;
	my $len = get_uint8($arrref);
	my $i;
	my $str;

	$str = '';
	for ($i = 0; $i < $len - 1 ; $i++ ) {
		$str .= pack("C",shift(@{$arrref}));
		shift @{$arrref};
	}
	return $str;
}

my $lastfunction;
my $lasttype = 0;

sub xml_handle_char {
	my ($expat, $str) = @_;
	my @bytes;

	if ($elemstack[$#elemstack] eq "function") {
		$lastfunction = $str;
		return;
	}
	if ($elemstack[$#elemstack] eq "endpoint") {
		$curep = $str;
		return;
	}
	# for the IN ep we only get the second mention of the URB
	# for the OUT ep we only get the first.
	if ($curep == 129) {
		return if ($urbenc{$curseq} == 1);
	} else {
		if ($curep == 2) {
			return if ($urbenc{$curseq} == 2);
		}
	}
	return unless ($elemstack[$#elemstack] eq "payloadbytes");
	if ($lastfunction ne "BULK_OR_INTERRUPT_TRANSFER") {
		print "str $str\n";
		return;
	}

	@bytes = unpack('C*',pack('H*',"\U$str"));

	my $length = get_uint32(\@bytes);
	my $type = get_uint16(\@bytes);

	#if ($length < $#bytes-6) {
	#	# print STDERR "$length < $#bytes\n";
	#	@bytes = @bytes[0..$length-7];
	#}

	if ($type == 1) {
		print "$curseq: COMMAND: ";
	} elsif ($type == 2) {
		# print "str is $str\n";
		# print "DATA: ";
		@curdata = ();
	} elsif ($type == 3) {
		return if ($urbenc{$curseq} == 1);
		print "$curseq: RESPONSE: ";
	} elsif ($type == 4) {
		print "$curseq: EVENT: ";
	} else {
		# printf "$curseq: TYPE %02x: ", $type;
		# print "$str\n";
		@bytes = unpack('C*',pack('H*',"\U$str"));
		push @curdata, @bytes;
		return;
	}
	my $code	= get_uint16(\@bytes);
	my $transid	= get_uint32(\@bytes);
	# not really needed .... print "transid $transid ";

	if ($type == 1) {
		$lastcode = $code;
		@curdata = ();
	}
	if ($type == 2) {
		push @curdata, @bytes;
		return;
	}
	dump_ptp_line($type,$code,\@bytes,\@curdata);
}

sub xml_handle_start {
	my ($expat, $element, $attr, $val) = @_;
	if (($element eq "urb") && ($attr eq "sequence")) {
		$curseq = $val;
		$urbenc{$val} = $urbenc{$val} + 1;
	}
	push @elemstack, $element;
}

sub xml_handle_end {
	my ($expat, $element) = @_;
	pop @elemstack;
}


# Evaluate and print out debug commands
# type == 1 	during send ... print parameters sent to camera
# type == 3	after response ... print data returned
#		@bytes - bulk container in response (no data)
#		@curdata - bulk data if command had seperate datastream
sub
dump_ptp_line() {
	my($type,$code,$bytesref,$curdataref) = @_;
	my @bytes = @{$bytesref};
	my @curdata = @{$curdataref};
	my $dummy;

	if ($type == 3) {
		if ($code == 0x2001) { print "OK(2001) - "; }
		elsif ($code == 0x2002) { print "GeneralError(2002) "; }
		elsif ($code == 0x2019) { print "DeviceBusy(2019) "; }
		else { printf "Unknown(%04x) ",$code; }
		$code = $lastcode;
	}

	if ($code == 0x1001) {
		if ($type == 1) {
			print "GetDeviceInfo(1001)\n";
		} elsif ($type == 3) {
			my $sver 	= get_uint16(\@curdata);
			$vendorid	= get_uint32(\@curdata);
			my $vendorextver= get_uint16(\@curdata);
			my $vendorextstr= get_str(\@curdata);
			my $funcmode	= get_uint16(\@curdata);

			print "GetDeviceInfo(1001)\n";
			print "\tStandardversion: $sver\n";
			print "\tVendorExtID: $vendorid\n";
			print "\tVendorExtVer: $vendorextver\n";
			print "\tVendorExtStr: $vendorextstr\n";
			printf "\tFunctionalMode: %x\n", $funcmode;
		}
		return;
	} elsif (($vendorid == 11) && ($code == 0x9008)) {
		print "CANON Start Shooting Mode (9008)\n";
		return;
	} elsif (($vendorid == 11) && ($code == 0x900b)) {
		print "CANON ViewFinder On(900b)\n";
		return;
	} elsif (($vendorid == 11) && ($code == 0x900c)) {
		print "CANON ViewFinder Off(900c)\n";
		return;
	} elsif ($code == 0x1002) {
		printf "OpenSession(1002) id = 0x%08x\n", get_uint32(\@bytes);
		return;
	} elsif ($code == 0x1004) {
		if ($type == 1) {
			printf "GetStorageIds(1004)\n";
		} elsif ($type == 3) {
			my $nr;
			my $i;

			$nr = get_uint32(\@curdata);
			printf "GetStorageIds(1004) [%x]=", $nr;
			for ($i = 0; $i < $nr; $i++) {
				printf("0x%08x",get_uint32(\@curdata));
				if ($i != $nr-1) {
					print ",";
				}
			}
			print "\n";
		}
		return;
	} elsif ($code == 0x1005) {
		if ($type ==1 ) {
			my $sid = get_uint32(\@bytes);
			printf "GetStorageInfo(1005) storage=0x%08lx\n",$sid;
		} elsif ($type == 3) {
			my $storagetype		= get_uint16(\@curdata);
			my $filesystemtype	= get_uint16(\@curdata);
			my $accesscap		= get_uint16(\@curdata);
			my $maxcap		= get_uint32(\@curdata);	$dummy		= get_uint32(\@curdata);
			my $freespace		= get_uint32(\@curdata);	$dummy		= get_uint32(\@curdata);
			my $freeimages		= get_uint32(\@curdata);

			print "GetStorageInfo(1005) type $storagetype, filesystem $filesystemtype, accesscap $accesscap, freespace $freespace, freeimages $freeimages\n";
		}
		return;
	} elsif ($code == 0x1014) {
		if ($type == 1) {
			my $prop = get_uint16(\@bytes);
			printf "GetDevicePropDesc(1014) prop = %04x\n", $prop;
		} elsif ($type == 3) {
			print "GetDevicePropDesc(1014)\n";
			hexdump(@curdata);
		}
		return;
	} elsif ($code == 0x1006) {
		if ($type == 1) {
			my $p1 = get_uint32(\@bytes);
			my $p2 = get_uint32(\@bytes);
			my $p3 = get_uint32(\@bytes);
			printf "GetNumObjects(1006) 0x%08lx,0x%08lx,0x%08lx\n", $p1,$p2,$p3;
		} elsif ($type == 3) {
			my $p1 = get_uint32(\@bytes);
			print "GetNumObjects(1006) num=$p1\n";
		}
		return;
	} elsif ($code == 0x1015) {
		if ($type == 1) {
			my $prop = get_uint32(\@bytes);
			printf "GetDevicePropValue(1015) prop = %04x\n", $prop;
		} elsif ($type == 3) {
			print "GetDevicePropValue(1015) data: ";
			hexdump(@curdata);
		}
		return;
	} elsif ($code == 0x1016) {
		if ($type == 1) {
			my $prop = get_uint32(\@bytes);
			printf "SetDevicePropValue(1016) prop = %04x, " . join(",",@bytes) . "\n", $prop;
		} elsif ($type == 3) {
			print "SetDevicePropValue(1016) data: ";
			hexdump(@curdata);
		}
		return;
	} elsif ($code == 0x1007) {
		if ($type == 1) {
			my $sid		= get_uint32(\@bytes);
			my $ofc		= get_uint32(\@bytes);
			my $assoc	= get_uint32(\@bytes);
			printf("GetObjectHandles(1007) 0x%08x 0x%08x 0x%08x\n", $sid, $ofc, $assoc);
		} elsif ($type == 3) {
			print "GetObjectHandles(1007) . "+join(",",@curdata) . "\n";
		}
		return;
	} elsif ($code == 0x1008) {
		if ($type ==1 ) {
			my $obid	= get_uint32(\@bytes);
			my $xx		= get_uint32(\@bytes);
			printf("GetObjectInfo(1008) object=0x%08lx, xx=0x%08lx\n", $obid, $xx);
		} elsif ($type == 3) {
			my $sid		= get_uint32(\@curdata);	# 0
			my $of		= get_uint16(\@curdata);	# 4
			my $protect	= get_uint16(\@curdata);	# 6
			my $compsize	= get_uint32(\@curdata);	# 8
			my $thumbof	= get_uint16(\@curdata);	# 12
			my $thumbsize	= get_uint32(\@curdata);	# 14
			my $thumbwidth	= get_uint32(\@curdata);	# 18
			my $thumbheight	= get_uint32(\@curdata);	# 22
			my $width	= get_uint32(\@curdata);	# 26
			my $height	= get_uint32(\@curdata);	# 30
			my $depth	= get_uint32(\@curdata);	# 34
			my $parent	= get_uint32(\@curdata);	# 38
			my $assoctype	= get_uint16(\@curdata);	# 42
			my $assocdesc	= get_uint32(\@curdata);	# 44
			my $seqnr	= get_uint32(\@curdata);	# 48
			my $filename	= get_str(\@curdata);		# 52
			my $capdate	= get_str(\@curdata);
			my $moddate	= get_str(\@curdata);

			print "GetObjectInfo(1008)\n";
			print "\tFileName: $filename\n";
			print "\tcapturedate: $capdate\n";
			print "\tmodificationdate: $moddate\n";
			printf "\tStorageID: %08lx\n", $sid;
			printf "\tOFC: %04x\n",$of;
		}
		return;
	} elsif ($code == 0x101b) {
		if ($type == 1 ) {
			my $obid	= get_uint32(\@bytes);
			my $offset	= get_uint32(\@bytes);
			my $maxbytes	= get_uint32(\@bytes);
			printf("GetPartialObject(1008) object=0x%08lx, offset=%d, maxbytes=%d\n", $obid,$offset, $maxbytes);
		} elsif ($type == 3) {
			print "GetPartialObject(1008) ... data ...\n";
			@curdata = ();
			@bytes = ();
		}
		return;
	} elsif (($vendorid == 11) && ($code == 0x9014)) {
		if ($type ==1 ) {
			print "FocusLock(9014)\n";
		} elsif ($type == 3) {
			printf("FocusLock(9014) ...\n");
		}
		return;
	} elsif (($vendorid == 11) && ($code == 0x9015)) {
		if ($type ==1 ) {
			print "FocusUnlock(9015)\n";
		} elsif ($type == 3) {
			printf("FocusUnlock(9015) ...\n");
		}
		return;
	} elsif (($vendorid == 11) && ($code == 0x9020)) {
		if ($type ==1 ) {
			print "CANON GetChanges(9020)\n";
		} elsif ($type == 3) {
			print "CANON GetChanges(9020) ";
			my $len = get_uint32(\@curdata);
			my $i;
			print " codes[$len] = {";
			for ($i = 0; $i < $len ; $i++) {
				my $code = get_uint16(\@curdata);
				printf("%04x,",$code);
			}
			print "}\n";
		}
		return;
	} elsif (($vendorid == 11) && ($code == 0x9013)) {
		if ($type == 1) {
			print "CANON CheckEvent(9013)\n";
		} elsif ($type == 3) {
			my $i;
			my $len = get_uint32(\@bytes);
			my $type = get_uint16(\@bytes);
			my $code = get_uint16(\@bytes);
			my $transid = get_uint32(\@bytes);
			printf("CANON CheckEvent(9013) len = $len, type = %04x, code = %04x, ", $type, $code);
			my $x;

			if ($len > 12 + 4*4) {
				$len = 12+4*4;
			}

			for  ($i = 12; $i < $len ; $i += 4 ) {
				$x = get_uint32(\@bytes);
				printf ("%08x,", $x);
			}
			print "\n";
		}
		return;
	} elsif (($vendorid == 10) && ($code == 0x9007)) {
		if ($type == 1) {
			my $profnr = get_uint32(\@bytes);
			print "NIKON UploadProfile(9007) nr=$profnr\n";
		} elsif ($type == 3) {
			print "NIKON UploadProfile(9007), data:\n";
			hexdump(@curdata);
		}
		return;
	} elsif ($code == 0x2001) {
		my $code = get_uint32(\@bytes);
		print "OK(2001) code=$code";
		hexdump(@bytes);
		print "\n";
		return;
	} elsif ($code == 0x400d) {
		print "CaptureComplete(400d)";
	} else {
		printf "%04x ", $code;
	}
	hexdump (@bytes);
	# print "str: $str\n";
}
