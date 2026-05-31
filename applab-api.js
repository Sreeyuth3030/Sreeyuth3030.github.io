// Citation: Data imported from the Code.org data table 
//           "NBA Teams" column "Team"
var teams = getColumn("NBA Teams", "Team");
// Citation: Data imported from the Code.org data table 
//           "NBA Teams" column "Conference"
var conf = getColumn("NBA Teams", "Conference");
// Citation: Data imported from the Code.org data table 
//           "NBA Teams" column "Arena"
var arena = getColumn("NBA Teams", "Arena");
// Citation: Data imported from the Code.org data table 
//           "NBA Teams" column "Championship wins"
var champion = getColumn("NBA Teams", "Championship wins");



// sets the options in the dropdown menu to all the teams in the NBA
setProperty("chooseDropDown", "options", teams);



// when a team is selected it shows the conference,arena, and championship wins
onEvent("chooseDropDown", "input", function( ) {
  var team = getText("chooseDropDown");
  results(team,teams,champion,arena,conf);
});









// sets the value of conference,state, and nickname based on the team selected
// @param {String} targeteam - the team selected
// @param {Array} teams - the array of all the teams in the NBA
// @param {Array} champion - the array of how many championships a given team has
// @param {Array} arena - the array of the arena that each team plays in
// @param {Array} conf - the array of the conference that the team plays in
function results(targeteam,teams,champion,arena,conf) {
  for(var i = 0; i < teams.length; i++){
    if(targeteam == teams[i]){
      setProperty("confResultsText","text", conf[i]);
      setProperty("arenaResultText","text", arena[i]);
      setProperty("championshipResultText","text", champion[i]);
    }
  }
}


// NBA Logo Image: https://blog.logomyway.com/wp-content/uploads/2017/01/nba-logo-design.jpg

