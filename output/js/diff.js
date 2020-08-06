/* JavaScript routines for diff files */

$(".last-picker").click(function () {
   /*thisWitId = $(this).parent().children(".label").text();*/
   thisWitId = $(this).parents("tr").attr("class").match(/a-w-\S+|e-[ab]/g)[0];
   $(".a-last").removeClass("a-last");
   console.log("Witness id: ", thisWitId);
   $(this).addClass("a-last");
   $(".e-u." + thisWitId).addClass("a-last");
   $("div.e-diff div." + thisWitId).addClass("a-last");
});
$(".other-picker").click(function () {
   thisWitId = $(this).parents("tr").attr("class").match(/a-w-\S+|e-[ab]/g)[0];
   $(".a-other").removeClass("a-other");
   console.log("Witness id: ", thisWitId);
   $(this).addClass("a-other");
   $(".e-u." + thisWitId).addClass("a-other");
   $("div.e-diff div." + thisWitId).addClass("a-other");
});
$(".switch").click(function () {
   /* This function turns witnesses on and off */
   $(this).children().toggle();
   $(this).parents("tr").toggleClass('suppressed');
   var arOn =[];
   $("table.e-stats > tbody > tr:not(.suppressed):not(.a-diff):not(.a-collation)").each(function () {
      thisAttrClass = $(this).attr("class").match(/a-w-\S+|e-[ab]/g)[0];
      console.log("this attr class:", thisAttrClass);
      arOn.push(thisAttrClass);
   });
   console.log("Witnesses to show: ", arOn, arOn.length);
   $("div.e-u, div.e-a, div.e-b").each(function () {
      thisAttrClass = $(this).attr("class");
      theseClasses = thisAttrClass.match(/a-w-\S+|e-[ab]/g);
      commonWitnesses = arOn.filter(value => theseClasses.includes(value));
      console.log("These witnesses: ", theseClasses, theseClasses.length);
      console.log("Witnesses that must be shown: ", commonWitnesses);
      if (commonWitnesses.length > 0) {
         $(this).removeClass("hide");
      } else {
         $(this).addClass("hide");
      };
      
   });
});
$(".label").click(function() {
   $(this).nextAll("div, table").toggle("fast");
});