package ZPAY::PAYLEAP;


__DATA__

<html>
<!-- 
DISCLAIMER:
THIS SOFTWARE IS PROVIDED BY PAYLEAP `AS IS'' AND ANY EXPRESSED OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL PAYLEAP OR ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.  QUESTIONS, COMMENTS, OR CONCERNS CAN BE DIRECTED TO INTEGRATION@PAYLEAP.COM

AVAILABLE WEB SERVICE API GUIDES:
http://www.payleap.com/developer/guides/transactionapi.pdf
http://www.payleap.com/developer/guides/scm.pdf
http://www.payleap.com/developer/guides/reportingapi.pdf

PLEASE EMAIL INTEGRATION@PAYLEAP.COM TO REQUEST A TEST ACCOUNT
-->
<head><title>PayLeap Test Credit Card Transaction</title></head>
<body>
<form method ="post" action="http://www.yourserver.com/creditcard_sale.php"> <!-- the forms location on your server -->
<input type="submit"  value="submit">
</form>
<?php
function payleap_send($packet, $url) {
$header = array("MIME-Version: 1.0","Content-type: application/x-www-form-urlencoded","Contenttransfer-encoding: text"); 
$ch = curl_init();
 
// set URL and other appropriate options 
curl_setopt($ch, CURLOPT_URL, $url); 
curl_setopt($ch, CURLOPT_VERBOSE, 1); 
curl_setopt ($ch, CURLOPT_PROXYTYPE, CURLPROXY_HTTP); 
// uncomment for host with proxy server
// curl_setopt ($ch, CURLOPT_PROXY, "http://proxyaddress:port"); 
curl_setopt($ch, CURLOPT_HTTPHEADER, $header); 
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, FALSE); 
curl_setopt($ch, CURLOPT_POST, true); 
curl_setopt($ch, CURLOPT_POSTFIELDS, $packet); 
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true); 
curl_setopt ($ch, CURLOPT_TIMEOUT, 10); 

// send packet and receive response
$response = curl_exec($ch); 
curl_close($ch); 
return($response);
}
if(getenv("REQUEST_METHOD") == "POST")
	{
	// build the HTTP request
    $args = "&Username=API USERNAME"; //Your API Username which can be located in your PayLeap merchant interface
    $args .= "&Password=TRANSACTION KEY"; //Your Transaction Key which can be located in your PayLeap merchant interface
    $args .= "&TransType=Sale";  // Review guide for transaction types
    $args .= "&NameOnCard=John Doe";
    $args .= "&CardNum=4111111111111111";
    $args .= "&ExpDate=0215"; //MMYY Format
	$args .= "&CVNum=123";
    $args .= "&Amount=9.95";
    $args .= "&ExtData=<TrainingMode>F</TrainingMode><Invoice><InvNum>111</InvNum><BillTo><Name>John Doe</Name><Address><Street>111 Street</Street><City>Seattle</City>
	<State>WA</State><Zip>98444</Zip><Country>USA</Country></Address><Email>test@test.com</Email><Phone>5555551212</Phone></BillTo><Description>Test Transaction</Description></Invoice>";
	$args .= "&PNRef=";
    $args .= "&MagData=";    

    // test environment: https://uat.payleap.com/TransactServices.svc/ProcessCreditCard
	// live environment: https://secure1.payleap.com/TransactServices.svc/ProcessCreditCard
	// your credentials will only work properly in the environment they were issued for
    $result = payleap_send($args, "https://uat.payleap.com/TransactServices.svc/ProcessCreditCard");
	// display results
	 echo htmlentities($result); 
	}
?>
