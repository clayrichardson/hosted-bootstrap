var casper = require('casper').create({
    pageSettings: {
        loadImages: false,//The script is much faster when this field is set to false
        loadPlugins: false,
        userAgent: 'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/44.0.2403.157 Safari/537.36'
    }
});

//First step is to open Amazon
//casper.start().thenOpen("https://aka.ms/devicelogin", function() {
casper.start().thenOpen("https://aka.ms/devicelogin", function() {
    console.log("Azure console opened");
    var js = this.evaluate(function(){
       return document;
      });
      console.log(js.all[0].outerHTML);
});

//Second step is to click to the Sign-in button
//Now we have to populate username and password, and submit the form
// casper.then(function(){
//     console.log("Login using username and password");
//     this.evaluate(function(){
//         document.getElementById("ap_email").value="AMAZON USERNAME";
//         document.getElementById("ap_password").value="AMAZON PASSWORD";
//         document.getElementById("signInSubmit").click();
//     });
// });

//Wait to be redirected to the Home page, and then make a screenshot
 casper.then(function(){
     console.log("Make a screenshot and save it as screen.png");
     this.capture('screen.png');
 });

casper.run();
