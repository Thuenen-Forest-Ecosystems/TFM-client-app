const TESTFN = (msg) => {
    console.log('TESTFN:', msg);
};

function fetchDatabaseData() {
    window.flutter_inappwebview.callHandler('fetchData').then(function(data) {
        console.log("Database Data:", data);
        alert(JSON.stringify(data));
    });
}