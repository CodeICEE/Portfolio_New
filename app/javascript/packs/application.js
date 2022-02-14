// This file is automatically compiled by Webpack, along with any other files
// present in this directory. You're encouraged to place your actual application logic in
// a relevant structure within app/javascript and only use these pack files to reference
// that code so it'll be compiled.

import Rails from "@rails/ujs"
//import Turbolinks from "turbolinks"
import "channels"

// Rails.start()
// Turbolinks.start()

window.onload = () => {

    //document.getElementById('project-1').addEventListener("click", addActive);
    
    function addActive(){
        let ele = document.getElementById('project-text');
        ele.classList.add("active");
        console.log("working")
    }

};
