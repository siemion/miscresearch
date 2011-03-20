#!/usr/bin/perl

# wikiupload.pl 
# syntax is wikiupload.pl <dir or wildcard> <comment>
# example: wikiupload.pl ~/*.png "My home dir pngs"
# note: must include trailing slash w/ directories, as in:
# wikiupload.pl /tmp/ "contents of /tmp"
# NOT: wikiupload.pl /tmp "contents of /tmp"


use File::Basename;
use Getopt::Long;
use LWP::Simple;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Response;
use HTTP::Cookies;
use Encode qw(encode);



#Edit these to point to the appropriate location
$mvs_command = "/opt/local/bin/mvs";
$convert_command = "/opt/local/bin/convert";


$username = "siemion";
$password = "somegreatpassword";
$wikipage = "User:Siemion";
$wiki_name = 'casper';
$wiki = 'http://casper.berkeley.edu/w/index.php';
$wiki_address = 'casper.berkeley.edu';


#these will be simply linked below the gallery
@extensions = ('gz', 'tar', 'ppt', 'mdl', 'bit', 'c', 'zip', 'rtf', 'txt', 'avi', 'mpg', 'mp3', 'doc', 'xls', 'psd');

#these will be placed in the gallery as-is
@images = ('png', 'gif', 'jpg', 'jpeg');

#these will be converted to pngs
@imconvert = ('eps', 'pdf', 'tif', 'tiff', 'ps');

$imgs_per_row = 5;
$widths=200;
$heights=200;

$pause = 2;



#Shouldn't have to edit anything below here.

sub uploadfile
{
# Note: Before usage, create an account on the destination MediaWiki
# for the bot. On Wikimedia Commons, the convention is
# "File Upload Bot (Username)", for example, File Upload Bot (Kernigh).
#
# Set the username and password below:


# Set the pause in seconds after each upload

my $wiki_name = $_[0];
my $wiki = $_[1]; 
my $username = $_[2];
my $password = $_[3];
my $dir = $_[4];

my %wiki_php = ($wiki_name, $wiki);

# dirname/ is the name of a directory containing the files to
# be uploaded, and a file named files.txt in the following format
#
# What you write                Explanation
#----------------------------------------------------------------------------
# @{{GFDL}} [[Category:Dog]]    This text is appended to every description.
# °Dog photo by Eloquence       This text is used when no description exists.
# >Dog01.jpg                    Name of a file in the specified directory.
# German shepherd dog           Description (can be multi-line).
# >Dog02.jpg                    File without a description (use default)
#
# The "@" and "°" lines are optional, and must be in one line. They can
# occur multiple times in a single file and are only valid until they
# are changed. As a consequence, description lines cannot start with "@"
# or "°".

my $ignore_login_error=0;
my $docstring="Please read mwup.pl for documentation.\n";

# Find the wiki PHP script
my $cgi = $wiki_php{$wiki_name} or die "Unknown wiki: $wiki\n$docstring";

# Make Unix style path
$dir=~s|\\|/|gi;

# Remove trailing slashes
my $sep=$/; $/="/"; chomp($dir); $/=$sep;

# Now try to get the list of files
open(FILELIST,"<$dir/files.txt")
  or die "Could not find file list at $dir/files.txt.\n$docstring";


$standard_text[0]="";
$default_text[0]="";
my $stx=0; 
my $dtx=0;
while(<FILELIST>) {
        my $line=$_;
        chomp($line);
        if($line=~m/^@/) {
                $line=~s/^@//;
                $standard_text[$stx]=$line;
                $stx++;
                $stw=1;
        }
        elsif($line=~m/^°/) {
                $line=~s/^°//;
                $default_text[$dtx]=$line;
                $dtx++;
                $dtw=1;
        }
        elsif($line=~m/^>/) {
                $line=~s/^>//;

                # New file, but last one doesn't have a description yet -
                # add current default.
                if($currentfile) {
                        # If there's been a change of the default or standard
                        # text, we need to apply the old text to the previous
                        # file, not the new one.
                        $dx= $dtw? $dtx-2 : $dtx -1;
                        $sx= $stw? $stx-2 : $stx -1;
                        if(!$desc_added) {
                                $file{$currentfile}.="\n".$default_text[$dx];
                        }
                        $file{$currentfile}.="\n\n".$standard_text[$sx];
                }
                # Abort the whole batch if this file doesn't exist.
                if(!-e "$dir/$line") {
                        die "Could not find $dir/$line. Uploading no files.\n"

                }
                $currentfile=$line;
                $desc_added=0;
                $dtw=0;$stw=0;
        }else {
                # If this is a header comment,
                # we just ignore it. Otherwise
                # it's a file description.
                if($currentfile) {
                        $file{$currentfile}.="\n".$line;
                        $desc_added=1;
                }
        }
}

# Last file needs to be processed, too
if($currentfile) {
        $dx= $dtw? $dtx-2 : $dtx -1;
        $sx= $stw? $stx-2 : $stx -1;
        if(!$desc_added) {
                $file{$currentfile}.="\n".$default_text[$dx];
        }
        $file{$currentfile}.="\n\n".$standard_text[$sx];
}

my $browser=LWP::UserAgent->new();
  my @ns_headers = (
   'User-Agent' => 'Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7) Gecko/20041107 Firefox/1.0',
   'Accept' => 'image/gif, image/x-xbitmap, image/jpeg,
        image/pjpeg, image/png, */*',
   'Accept-Charset' => 'iso-8859-1,*,utf-8',
   'Accept-Language' => 'en-US',
  );

$browser->cookie_jar( {} );

$response=$browser->post("$cgi?title=Special:Userlogin&action=submitlogin",
@ns_headers, Content=>[wpName=>$username,wpPassword=>$password,wpRemember=>"1",wpLoginAttempt=>"Log in"]);

# After logging in, we should be redirected to another page.
# If we aren't, something is wrong.
#
if($response->code!=302 && !$ignore_login_error) {
        print
"We weren't able to login. This could have the following causes:

* The username ($username) or password may be incorrect.
  Solution: Edit upload.pl and change them.
* The MediaWiki software has been upgraded.
  Solution: Go to (where?)
  and get a new version of the upload script.
* You are trying to hack this script for other wikis. The wiki you
  are uploading to has cookie check disabled.
  Solution: Try setting \$ignore_login_error to 1.

Regardless, we will now try to write the output from the server to
$dir/debug.txt....\n\n";
        open(DEBUG,">$dir/debug.txt") or die "Could not write file.\n";
        print DEBUG $response->as_string;
        print
"This seems to have worked. Take a look at the file for further information.\n";
        close(DEBUG);
        exit 1;
}

foreach $key(keys(%file)) {
        sleep $pause;
        print "Uploading $key to the wiki $wiki. Description:\n";
        print $file{$key}."\n" . "-" x 75 . "\n";
        uploadfile:
        $eckey=encode('utf8',$key);
        if($eckey ne $key) {
                symlink("$key","$dir/$eckey");
        }
        $response=$browser->post("$cgi?title=Special:Upload",
        @ns_headers,Content_Type=>'form-data',Content=>
        [
                wpUploadFile=>["$dir/$eckey"],
                wpUploadDescription=>encode('utf8',$file{$key}),
                wpUploadAffirm=>"1",
                wpUpload=>"Upload file",
                wpIgnoreWarning=>"1"
        ]);
        push @responses,$response->as_string;
        if($response->code!=302 && $response->code!=200) {
                print "Upload failed! Will try again. Output was:\n";
                print $response->as_string;
                goto uploadfile;
        } else {
                print "Uploaded successfully.\n";
        }
}

print "Everything seems to be OK. Log will be written to $dir/debug.txt.\n";
open(DEBUG,">$dir/debug.txt") or die "Could not write file.\n";
print DEBUG @responses;

}


sub generate_random_string
{
	my $length_of_randomstring=shift;# the length of 
			 # the random string to generate

	my @chars=('a'..'z','A'..'Z','0'..'9','_');
	my $random_string;
	foreach (1..$length_of_randomstring) 
	{
		# rand @chars will generate a random 
		# number between 0 and scalar @chars
		$random_string.=$chars[rand @chars];
	}
	return $random_string;
}


#GetOptions ('p:s' => \$path, 'c:s' => \$comment, 'im:s' => \$comment);

$ignore_login_error=0;
$docstring="Syntax: perl wikiupload.pl <directory or file> <comment>\n";
my $dir=$ARGV[0] or die  "$docstring";
my $comment=$ARGV[1] or die "$docstring";

$dir =~ s/([ ])/\\$1/g;

(@files) = glob($dir."*");
#print @files;
#print "num: ".$#files."\n";

if($#files < 0) {
	die "no files to process...\n";
}

my $random_string=&generate_random_string(8);

@months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
@weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
$year = 1900 + $yearOffset;
$theTime = "$hour:$minute:$second, $weekDays[$dayOfWeek] $months[$month] $dayOfMonth, $year";
#print $theTime;


system( 'mkdir /tmp/'.$random_string); 
system( 'mkdir /tmp/'.$random_string.'/'.$wiki_name); 


system ('echo "<br style=\'clear:both\' />" >> /tmp/'.$random_string.'/wiki.txt');
system ('echo "=='.$theTime.'==" >> /tmp/'.$random_string.'/wiki.txt');

#or die "couldn't mk temp dir";


system ('echo "<br style=\'clear:both\' />" >> /tmp/'.$random_string.'/wiki.txt');	 
$imgcnt = 0;

foreach $file (@files) {
	$file =~ s/([ ])/\\$1/g;
}

foreach $file (@files) {
	
	($name,$path,$suffix) = fileparse($file);
	($iname,$path,$isuffix) = fileparse($file, @images);
	$name =~ s/%/_/g;
	$name =~ s/([ ])/\\$1/g;

	if($isuffix ne ''){
		if($imgcnt == 0) {
			system ('echo "<gallery caption=\''.$comment.'\' widths=\''.$widths.'px\' heights=\''.$heights.'px\' perrow=\'5\'>" >> /tmp/'.$random_string.'/wiki.txt');	 			
		}
		system ('cp '.$file.' /tmp/'.$random_string.'/'.$random_string.'_'.$name);
		system ('echo ">'.$random_string.'_'.$name.'" >> /tmp/'.$random_string.'/files.txt');
		system ('echo "'.$comment.'" >> /tmp/'.$random_string.'/files.txt');
		system ('echo "Image:' .$random_string.'_'.$name.'|'.$name.'" >> /tmp/'.$random_string.'/wiki.txt');
		$imgcnt = $imgcnt + 1;
	} 
}

foreach $file (@files) {
	
	($name,$path,$suffix) = fileparse($file);
	($iname,$path,$isuffix) = fileparse($file, @imconvert);
	$name =~ s/%/_/g;
	$name =~ s/([ ])/\\$1/g;
	if($isuffix ne ''){
		if($imgcnt == 0) {
			system ('echo "<gallery caption=\''.$comment.'\' widths=\''.$widths.'px\' heights=\''.$heights.'px\' perrow=\'5\'>" >> /tmp/'.$random_string.'/wiki.txt');	 			
		}
		system ('cp '.$file.' /tmp/'.$random_string.'/'.$random_string.'_'.$name);

		system ($convert_command.' /tmp/'.$random_string.'/'.$random_string.'_'.$name.' -append /tmp/'.$random_string.'/'.$random_string.'_'.$name.'.png');

		system ('echo "Image:' .$random_string.'_'.$name.'.png|[[Media:'.$random_string.'_'.$name.'|Vector version of '.$name.']]" >> /tmp/'.$random_string.'/wiki.txt');

		system ('echo ">'.$random_string.'_'.$name.'" >> /tmp/'.$random_string.'/files.txt');
		system ('echo "'.$comment.'" >> /tmp/'.$random_string.'/files.txt');

		system ('echo ">'.$random_string.'_'.$name.'.png" >> /tmp/'.$random_string.'/files.txt');
		system ('echo "'.$comment.'" >> /tmp/'.$random_string.'/files.txt');

		$imgcnt = $imgcnt + 1;
	} 
}



if($imgcnt > 0) {
	system ('echo "</gallery>" >> /tmp/'.$random_string.'/wiki.txt');	 			
}

foreach $file (@files) {

	($name,$path,$suffix) = fileparse($file);
	($ename,$path,$esuffix) = fileparse($file, @extensions);
	$name =~ s/%/_/g;
	$name =~ s/([ ])/\\$1/g;
	
	if($esuffix ne ''){
		system ('cp '.$file.' /tmp/'.$random_string.'/'.$random_string.'_'.$name);
		system ('echo ">'.$random_string.'_'.$name.'" >> /tmp/'.$random_string.'/files.txt');
		system ('echo "'.$comment.'" >> /tmp/'.$random_string.'/files.txt');
		system ('echo "{{bit|'.$random_string.'_'.$name.'|'.$name.'}}" >> /tmp/'.$random_string.'/wiki.txt');
		system ('echo "<br style=\'clear:both\' />" >> /tmp/'.$random_string.'/wiki.txt');	 
	}

}

#upload directory full of files
uploadfile($wiki_name, $wiki, $username, $password, '/tmp/'.$random_string);

system ('cd /tmp/'.$random_string.'/'.$wiki_name.'; '.$mvs_command.' login -d '.$wiki_address.' -u '.$username.' -p \''.$password.'\' -w /w/index.php');
system ('cd /tmp/'.$random_string.'/'.$wiki_name.'; '.$mvs_command.' update '.$wikipage.'.wiki');
system ('cat /tmp/'.$random_string.'/wiki.txt >> /tmp/'.$random_string.'/'.$wiki_name.'/'.$wikipage.'.wiki');
system ('cd /tmp/'.$random_string.'/'.$wiki_name.'; '.$mvs_command.' commit -m \'automated edit\' '.$wikipage.'.wiki');


