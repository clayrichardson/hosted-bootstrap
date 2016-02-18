// adapted from: http://code-epicenter.com/how-to-login-amazon-using-phantomjs-working-example/

var system = require('system');
var webPage = require('webpage');

var steps=[];
var testindex = 0;
var loadInProgress = false; //This is set to true when a page is still loading

/*********SETTINGS*********************/
var page = webPage.create();
page.viewportSize = {
    width: 1920,
    height: 1080
};
page.settings.userAgent = 'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/44.0.2403.157 Safari/537.36';
page.settings.javascriptEnabled = true;
page.settings.loadImages = true; //Script is much faster with this field set to false
phantom.cookiesEnabled = true;
phantom.javascriptEnabled = true;
/*********SETTINGS END*****************/
/*********CONFIG*****************/
var configs = {};
configs.token = system.env['AZURE_CLI_TOKEN'];
configs.username = system.env['SECRET_AZURE_CLI_USERNAME'];
configs.password = system.env['SECRET_AZURE_CLI_PASSWORD'];
/*********CONFIG END*****************/
console.log('All settings loaded, start with execution');
page.onConsoleMessage = function(msg) {
    console.log(msg);
};
/**********DEFINE STEPS THAT FANTOM SHOULD DO***********************/
steps = [
    //Step 1 - Open AKA home page
    function(){
        console.log('Step 1 - Open aka.ms home page');
        page.open("https://aka.ms/devicelogin", function(status){

        });
    },
    //Step 2 - Input the code
    function(){
        console.log('Step 2 - input code');
        page.evaluate(function(){
            document.getElementById("code").focus();
        });
        console.log(configs.token);
        page.sendEvent('keypress', configs.token);
    },
    // Step 3 - Click the continue button
    function(){
        console.log('Step 3 - click continue button');
        page.evaluate(function(){
            document.getElementById("continueBtn").click();
        });
    },
    //Step 4 - Login

    function(){
        console.log('Step 4 - login');

        page.evaluate(function(configs){
            document.getElementById("cred_userid_inputtext").value = configs.username;
            document.getElementById("cred_password_inputtext").value = configs.password;
            document.getElementById("cred_sign_in_button").click();
        }, configs);
    },
    //Step 5 - Login again
    function(){
        console.log('Step 5 - Login again');
        page.evaluate(function(configs){
            document.getElementById("i0116").value = configs.username;
            document.getElementById("i0118").value = configs.password;
            document.getElementById("idSIButton9").click();
        }, configs);
    },
    //Step 6 - screenshot
    function(){
        console.log('Step 6 - screenshot');
        page.render('./output/screen.png')
    },

];
/**********END STEPS THAT PHANTOM SHOULD DO***********************/

//Execute steps one by one
interval = setInterval(executeRequestsStepByStep,6000);

function executeRequestsStepByStep(){
    if (loadInProgress == false && typeof steps[testindex] == "function") {
        steps[testindex]();
        testindex++;
    }
    if (typeof steps[testindex] != "function") {
        console.log("login complete!");
        phantom.exit();
    }
}

/**
 * These listeners are very important in order to phantom work properly. Using these listeners, we control loadInProgress marker which controls, weather a page is fully loaded.
 * Without this, we will get content of the page, even a page is not fully loaded.
 */
page.onLoadStarted = function() {
    loadInProgress = true;
    console.log('Loading started');
};
page.onLoadFinished = function() {
    loadInProgress = false;
    console.log('Loading finished');
};
page.onConsoleMessage = function(msg) {
    console.log(msg);
};

