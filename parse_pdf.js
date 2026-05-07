const fs = require('fs');
const pdf = require('pdf-parse');

let dataBuffer = fs.readFileSync('C:\\Users\\edgar\\Downloads\\SAHARA CLUB w&b (1).pdf');

pdf(dataBuffer).then(function(data) {
    fs.writeFileSync('C:\\Proyectos\\sahara-club-spa-web\\pdf_content.txt', data.text);
    console.log("DONE");
}).catch(err => {
    console.error(err);
});
