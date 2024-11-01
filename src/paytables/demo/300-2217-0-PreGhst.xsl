<?xml version="1.0" encoding="UTF-8" ?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:x="anything">
	<xsl:namespace-alias stylesheet-prefix="x" result-prefix="xsl" />
	<xsl:output encoding="UTF-8" indent="yes" method="xml" />
	<xsl:include href="../utils.xsl" />

	<xsl:template match="/Paytable">
		<x:stylesheet version="1.0" xmlns:java="http://xml.apache.org/xslt/java" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
			exclude-result-prefixes="java" xmlns:lxslt="http://xml.apache.org/xslt" xmlns:my-ext="ext1" extension-element-prefixes="my-ext">
			<x:import href="HTML-CCFR.xsl" />
			<x:output indent="no" method="xml" omit-xml-declaration="yes" />

			<!-- TEMPLATE Match: -->
			<x:template match="/">
				<x:apply-templates select="*" />
				<x:apply-templates select="/output/root[position()=last()]" mode="last" />
				<br />
			</x:template>

			<!--The component and its script are in the lxslt namespace and define the implementation of the extension. -->
			<lxslt:component prefix="my-ext" functions="formatJson,retrievePrizeTable,getType">
				<lxslt:script lang="javascript">
					<![CDATA[
					var debugFeed = [];
					var debugFlag = false;
					var bonusTotal = 0; 
					// Format instant win JSON results.
					// @param jsonContext String JSON results to parse and display.
					// @param translation Set of Translations for the game.
					function formatJson(jsonContext, translations, prizeTable, prizeValues, prizeNamesDesc)
					{
						var scenario = getScenario(jsonContext);
						var scenarioMainGame = getMainGameData(scenario);
						var scenarioFreePlays = getFreePlaysData(scenario);
						var scenarioInstantWins = getInstantWinsData(scenario);
						var scenarioLAKBonus = getLAKBonusData(scenario);
						var convertedPrizeValues = (prizeValues.substring(1)).split('|');
						var prizeNames = (prizeNamesDesc.substring(1)).split(',');

						////////////////////
						// Parse scenario //
						////////////////////

						const gridCols 		= 5;
						const gridRows 		= 3;
						const freePlayGames = 3;
						const battleRounds  = 3;
						const battleTurns   = 5;

						const symbPrizes     = 'ABCDEFG';
						const symbFreePlay   = 'P';
						const symbInstantWin = 'I';
						const symbLock       = 'L';
						const symbKey        = 'K';
						const symbWild       = 'W';
						const symbSpecials   = symbFreePlay + symbInstantWin + symbLock + symbKey + symbWild;

						var doFreePlays  = (scenarioFreePlays.length == freePlayGames);
						var doInstantWin = (scenarioInstantWins != '');
						var doLAKBonus   = (scenarioLAKBonus.length == battleRounds);

						// want arrPhases to be an array {phases} of objects: var objPhase = {}
						// assign objPhase.arrGrid = array {cols} of 3-char strings: just arrGrid column data at beginning of phase
						// assign objPhase.arrClusters = array {arrClusters} of objects: var objCluster = {};
						//    assign objPhase.arrClusters.arrCells = array {cells} of integers: the cells of the cluster
						//    assign objPhase.arrClusters.strPrize = string: first non-W cell in cluster
						// assign objPhase.arrBonusCells = array {cells} of integers: the cells that trigger the bonus

						// arrPhases = array {phases} of object {arrGrid: array {cols} of 3-char strings
						//                                       arrClusters: array {phase-clusters} of object {arrCells: array {cluster-cells} of integers
						//                                                                                      strPrize: string
						//                                                                                     }
						//                                       arrBonusCells: array {cells} of integers
						//                                      }

						var arrGridData  = [];
						var arrAuditData = [];

						function getPhasesData(A_arrGridData, A_arrAuditData)
						{
							var arrBonusCells = [];
							var arrClusters   = [];
							var arrPhaseCells = [];
							var arrPhases     = [];
							var objCluster    = {};
							var objPhase      = {};							
							var cellCol       = -1;
							var cellRow       = -1;
							var posW          = -1;

							if (A_arrAuditData != '')
							{
								for (var phaseIndex = 0; phaseIndex < A_arrAuditData.length; phaseIndex++)
								{
									objPhase = {arrGrid: [], arrClusters: [], arrBonusCells: []};

									for (var colIndex = 0; colIndex < gridCols; colIndex++)
									{
										objPhase.arrGrid.push(A_arrGridData[colIndex].substr(0,gridRows));
									}

									arrClusters   = A_arrAuditData[phaseIndex].split(":");
									arrPhaseCells = [];

									for (var clusterIndex = 0; clusterIndex < arrClusters.length; clusterIndex++)
									{
										objCluster = {arrCells: [], strPrize: ''};

										objCluster.arrCells = arrClusters[clusterIndex].match(new RegExp('.{1,2}', 'g')).map(function(item) {return parseInt(item,10);} );

										objCluster.strPrize = objCluster.arrCells.map(function(item) {return objPhase.arrGrid.join("")[item-1];} ).join("").match(new RegExp('[^W]'));

										objPhase.arrClusters.push(objCluster);

										arrPhaseCells = arrPhaseCells.concat(objCluster.arrCells.filter(function(item) {return objPhase.arrGrid.join("")[item-1] != symbWild;} ));
									}

									arrPhases.push(objPhase);

									arrPhaseCells.sort(function(a,b) {return b-a;} );

									for (var cellIndex = 0; cellIndex < arrPhaseCells.length; cellIndex++)
									{
										cellCol = Math.floor((arrPhaseCells[cellIndex]-1) / gridRows);
										cellRow = (arrPhaseCells[cellIndex]-1) % gridRows;

										if (cellCol >= 0 && cellCol < gridCols)
										{
											posW = A_arrGridData[cellCol].indexOf(symbWild);

											if (posW > cellRow)
											{
												A_arrGridData[cellCol] = A_arrGridData[cellCol].substring(0,posW) + A_arrGridData[cellCol][posW+1] + A_arrGridData[cellCol][posW] + A_arrGridData[cellCol].substring(posW+2);
											}
			
											A_arrGridData[cellCol] = A_arrGridData[cellCol].substring(0,cellRow) + A_arrGridData[cellCol].substring(cellRow+1);
										}
									}
								}
							}

							objPhase = {arrGrid: [], arrClusters: [], arrBonusCells: []};

							for (var colIndex = 0; colIndex < gridCols; colIndex++)
							{
								objPhase.arrGrid.push(A_arrGridData[colIndex].substr(0,gridRows));
							}

							if ((doFreePlays || doInstantWin || doLAKBonus) && objPhase.arrGrid.join("").indexOf(symbWild) == -1)
							{
								var bonusSymb = (doFreePlays) ? symbFreePlay : ((doInstantWin) ? symbInstantWin : symbLock + symbKey);

								objPhase.arrBonusCells = objPhase.arrGrid.join("").split("").map(function(item,index) {return (bonusSymb.indexOf(item) != -1) ? index+1 : -1;} ).filter(function(item) {return item != -1;});
							}

							arrPhases.push(objPhase);

							return arrPhases;
						}

						arrGridData  = scenarioMainGame.split(":")[0].split(",");
						arrAuditData = scenarioMainGame.split(":").slice(1).join(":").split(",");

						var mgPhases = getPhasesData(arrGridData, arrAuditData);
						var fpGames  = [];

						if (doFreePlays)
						{
							for (var freePlayIndex = 0; freePlayIndex < freePlayGames; freePlayIndex++)
							{
								arrGridData  = scenarioFreePlays[freePlayIndex].split(":")[0].split(",");
								arrAuditData = scenarioFreePlays[freePlayIndex].split(":").slice(1).join(":").split(",");

								fpGames.push(getPhasesData(arrGridData, arrAuditData));
							}
						}

						///////////////////////
						// Output Game Parts //
						///////////////////////

						const cellSize     = 24;
						const cellMargin   = 1;
						const cellTextX    = 13;
						const cellTextY    = 15;
						const colourBlack  = '#000000';
						const colourBlue   = '#99ccff';
						const colourGreen  = '#00ff00';
						const colourLemon  = '#ffff99';
						const colourLilac  = '#ccccff';
						const colourLime   = '#ccff99';
						const colourNavy   = '#0000ff';
						const colourOrange = '#ffcc99';
						const colourPink   = '#ffccff';
						const colourPurple = '#cc99ff';
						const colourRed    = '#ff0000';
						const colourWhite  = '#ffffff';
						const colourYellow = '#ffff00';

						const prizeColours       = [colourPink, colourOrange, colourLemon, colourLime, colourBlue, colourLilac, colourPurple];
						const specialBoxColours  = [colourRed, colourGreen, colourNavy, colourNavy, colourBlack];
						const specialTextColours = [colourYellow, colourBlack, colourYellow, colourYellow, colourWhite];

						var r = [];

						var boxColourStr = '';
						var canvasIdStr  = '';
						var elementStr   = '';
						var symbDesc     = '';
						var symbPrize    = '';
						var symbSpecial  = '';

						function showSymb(A_strCanvasId, A_strCanvasElement, A_strBoxColour, A_strTextColour, A_strText)
						{
							var canvasCtxStr = 'canvasContext' + A_strCanvasElement;

							r.push('<canvas id="' + A_strCanvasId + '" width="' + (cellSize + 2 * cellMargin).toString() + '" height="' + (cellSize + 2 * cellMargin).toString() + '"></canvas>');
							r.push('<script>');
							r.push('var ' + A_strCanvasElement + ' = document.getElementById("' + A_strCanvasId + '");');
							r.push('var ' + canvasCtxStr + ' = ' + A_strCanvasElement + '.getContext("2d");');
							r.push(canvasCtxStr + '.font = "bold 14px Arial";');
							r.push(canvasCtxStr + '.textAlign = "center";');
							r.push(canvasCtxStr + '.textBaseline = "middle";');
							r.push(canvasCtxStr + '.strokeRect(' + (cellMargin + 0.5).toString() + ', ' + (cellMargin + 0.5).toString() + ', ' + cellSize.toString() + ', ' + cellSize.toString() + ');');
							r.push(canvasCtxStr + '.fillStyle = "' + A_strBoxColour + '";');
							r.push(canvasCtxStr + '.fillRect(' + (cellMargin + 1.5).toString() + ', ' + (cellMargin + 1.5).toString() + ', ' + (cellSize - 2).toString() + ', ' + (cellSize - 2).toString() + ');');
							r.push(canvasCtxStr + '.fillStyle = "' + A_strTextColour + '";');
							r.push(canvasCtxStr + '.fillText("' + A_strText + '", ' + cellTextX.toString() + ', ' + cellTextY.toString() + ');');

							r.push('</script>');
						}

						///////////////////////
						// Prize Symbols Key //
						///////////////////////

						r.push('<div style="float:left; margin-right:50px">');
						r.push('<p>' + getTranslationByName("titlePrizeSymbolsKey", translations) + '</p>');

						r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
						r.push('<tr class="tablehead">');
						r.push('<td>' + getTranslationByName("keySymbol", translations) + '</td>');
						r.push('<td>' + getTranslationByName("keyDescription", translations) + '</td>');
						r.push('</tr>');

						for (var prizeIndex = 0; prizeIndex < symbPrizes.length; prizeIndex++)
						{
							symbPrize    = symbPrizes[prizeIndex];
							canvasIdStr  = 'cvsKeySymb' + symbPrize;
							elementStr   = 'keyPrizeSymb' + symbPrize;
							boxColourStr = prizeColours[prizeIndex];
							symbDesc     = 'symb' + symbPrize;

							r.push('<tr class="tablebody">');
							r.push('<td align="center">');

							showSymb(canvasIdStr, elementStr, boxColourStr, colourBlack, symbPrize);

							r.push('</td>');
							r.push('<td>' + getTranslationByName(symbDesc, translations) + '</td>');
							r.push('</tr>');
						}

						r.push('</table>');
						r.push('</div>');

						/////////////////////////
						// Special Symbols Key //
						/////////////////////////

						r.push('<div style="float:left">');
						r.push('<p>' + getTranslationByName("titleSpecialSymbolsKey", translations) + '</p>');

						r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
						r.push('<tr class="tablehead">');
						r.push('<td>' + getTranslationByName("keySymbol", translations) + '</td>');
						r.push('<td>' + getTranslationByName("keyDescription", translations) + '</td>');
						r.push('</tr>');

						for (var specialIndex = 0; specialIndex < symbSpecials.length; specialIndex++)
						{
							symbSpecial   = symbSpecials[specialIndex];
							canvasIdStr   = 'cvsKeySymb' + symbSpecial;
							elementStr    = 'keySpecialSymb' + symbSpecial;
							boxColourStr  = specialBoxColours[specialIndex];
							textColourStr = specialTextColours[specialIndex];
							symbDesc      = 'symb' + symbSpecial;

							r.push('<tr class="tablebody">');
							r.push('<td align="center">');

							showSymb(canvasIdStr, elementStr, boxColourStr, textColourStr, symbSpecial);

							r.push('</td>');
							r.push('<td>' + getTranslationByName(symbDesc, translations) + '</td>');
							r.push('</tr>');
						}

						r.push('</table>');
						r.push('</div>');

						///////////////
						// Main Game //
						///////////////

						var doTrigger        = false;
						var gridCanvasHeight = gridRows * cellSize + 2 * cellMargin;
						var gridCanvasWidth  = gridCols * cellSize + 2 * cellMargin;
						var phaseStr         = '';
						var triggerStr       = '';

						function showGridSymbs(A_strCanvasId, A_strCanvasElement, A_arrGrid)
						{
							var canvasCtxStr = 'canvasContext' + A_strCanvasElement;
							var cellX        = 0;
							var cellY        = 0;
							var isPrizeCell  = false;
							var symbCell     = '';
							var symbIndex    = -1;

							r.push('<canvas id="' + A_strCanvasId + '" width="' + gridCanvasWidth.toString() + '" height="' + gridCanvasHeight.toString() + '"></canvas>');
							r.push('<script>');
							r.push('var ' + A_strCanvasElement + ' = document.getElementById("' + A_strCanvasId + '");');
							r.push('var ' + canvasCtxStr + ' = ' + A_strCanvasElement + '.getContext("2d");');
							r.push(canvasCtxStr + '.textAlign = "center";');
							r.push(canvasCtxStr + '.textBaseline = "middle";');

							for (var gridCol = 0; gridCol < gridCols; gridCol++)
							{
								for (var gridRow = 0; gridRow < gridRows; gridRow++)
								{
									symbCell      = A_arrGrid[gridCol][gridRow];
									isPrizeCell   = (symbPrizes.indexOf(symbCell) != -1);
									symbIndex     = (isPrizeCell) ? symbPrizes.indexOf(symbCell) : symbSpecials.indexOf(symbCell);
									boxColourStr  = (isPrizeCell) ? prizeColours[symbIndex] : specialBoxColours[symbIndex];
									textColourStr = (isPrizeCell) ? colourBlack : specialTextColours[symbIndex];
									cellX         = gridCol * cellSize;
									cellY         = (gridRows - gridRow - 1) * cellSize;

									r.push(canvasCtxStr + '.font = "bold 14px Arial";');
									r.push(canvasCtxStr + '.strokeRect(' + (cellX + cellMargin + 0.5).toString() + ', ' + (cellY + cellMargin + 0.5).toString() + ', ' + cellSize.toString() + ', ' + cellSize.toString() + ');');
									r.push(canvasCtxStr + '.fillStyle = "' + boxColourStr + '";');
									r.push(canvasCtxStr + '.fillRect(' + (cellX + cellMargin + 1.5).toString() + ', ' + (cellY + cellMargin + 1.5).toString() + ', ' + (cellSize - 2).toString() + ', ' + (cellSize - 2).toString() + ');');
									r.push(canvasCtxStr + '.fillStyle = "' + textColourStr + '";');
									r.push(canvasCtxStr + '.fillText("' + symbCell + '", ' + (cellX + cellTextX).toString() + ', ' + (cellY + cellTextY).toString() + ');');
								}
							}

							r.push('</script>');
						}

						function showAuditSymbs(A_strCanvasId, A_strCanvasElement, A_arrGrid, A_arrData)
						{
							var canvasCtxStr = 'canvasContext' + A_strCanvasElement;
							var cellX        = 0;
							var cellY        = 0;
							var isPrizeCell  = false;
							var symbCell     = '';
							var symbIndex    = -1;
							var cellNum      = 0;
							var isWildCell   = false;

							r.push('<canvas id="' + A_strCanvasId + '" width="' + (gridCanvasWidth + 25).toString() + '" height="' + gridCanvasHeight.toString() + '"></canvas>');
							r.push('<script>');
							r.push('var ' + A_strCanvasElement + ' = document.getElementById("' + A_strCanvasId + '");');
							r.push('var ' + canvasCtxStr + ' = ' + A_strCanvasElement + '.getContext("2d");');
							r.push(canvasCtxStr + '.textAlign = "center";');
							r.push(canvasCtxStr + '.textBaseline = "middle";');

							for (var gridCol = 0; gridCol < gridCols; gridCol++)
							{
								for (var gridRow = 0; gridRow < gridRows; gridRow++)
								{
									cellNum++;

									isWildCell    = (A_arrGrid[gridCol][gridRow] == symbWild);
									symbCell      = ('0' + cellNum).slice(-2);
									symbIndex     = (!doTrigger && !isWildCell) ? symbPrizes.indexOf(A_arrData.strPrize) : symbSpecials.indexOf(A_arrGrid[gridCol][gridRow]);
									isPrizeCell   = (!doTrigger) ? (A_arrData.arrCells.indexOf(cellNum) != -1) : (A_arrData.indexOf(cellNum) != -1);
									boxColourStr  = (isPrizeCell) ? ((!doTrigger && !isWildCell) ? prizeColours[symbIndex] : specialBoxColours[symbIndex]) : colourWhite;									
									textColourStr = (isPrizeCell) ? ((!doTrigger && !isWildCell) ? colourBlack : specialTextColours[symbIndex]) : colourBlack;
									cellX         = gridCol * cellSize;
									cellY         = (gridRows - gridRow - 1) * cellSize;

									r.push(canvasCtxStr + '.font = "bold 14px Arial";');
									r.push(canvasCtxStr + '.strokeRect(' + (cellX + cellMargin + 0.5).toString() + ', ' + (cellY + cellMargin + 0.5).toString() + ', ' + cellSize.toString() + ', ' + cellSize.toString() + ');');
									r.push(canvasCtxStr + '.fillStyle = "' + boxColourStr + '";');
									r.push(canvasCtxStr + '.fillRect(' + (cellX + cellMargin + 1.5).toString() + ', ' + (cellY + cellMargin + 1.5).toString() + ', ' + (cellSize - 2).toString() + ', ' + (cellSize - 2).toString() + ');');
									r.push(canvasCtxStr + '.fillStyle = "' + textColourStr + '";');
									r.push(canvasCtxStr + '.fillText("' + symbCell + '", ' + (cellX + cellTextX).toString() + ', ' + (cellY + cellTextY).toString() + ');');
								}
							}

							r.push('</script>');
						}

						r.push('<p style="clear:both"><br>' + getTranslationByName("mainGame", translations) + '</p>');

						r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');

						for (var phaseIndex = 0; phaseIndex < mgPhases.length; phaseIndex++)
						{
							//////////////////////////
							// Main Game Phase Info //
							//////////////////////////

							phaseStr = getTranslationByName("phaseNum", translations) + ' ' + (phaseIndex+1).toString() + ' ' + getTranslationByName("phaseOf", translations) + ' ' + mgPhases.length.toString();

							r.push('<tr class="tablebody">');
							r.push('<td valign="top">' + phaseStr + '</td>');

							////////////////////
							// Main Game Grid //
							////////////////////

							canvasIdStr = 'cvsMainGrid' + phaseIndex.toString();
							elementStr  = 'phaseMainGrid' + phaseIndex.toString();

							r.push('<td style="padding-left:50px; padding-right:50px; padding-bottom:25px">');

							showGridSymbs(canvasIdStr, elementStr, mgPhases[phaseIndex].arrGrid);

							r.push('</td>');

							/////////////////////////////////////////
							// Main Game Clusters or trigger cells //
							/////////////////////////////////////////

							r.push('<td style="padding-right:50px; padding-bottom:25px">');

							for (clusterIndex = 0; clusterIndex < mgPhases[phaseIndex].arrClusters.length; clusterIndex++)
							{
								canvasIdStr = 'cvsMainAudit' + phaseIndex.toString() + '_' + clusterIndex.toString();
								elementStr  = 'phaseMainAudit' + phaseIndex.toString() + '_' + clusterIndex.toString();

								showAuditSymbs(canvasIdStr, elementStr, mgPhases[phaseIndex].arrGrid, mgPhases[phaseIndex].arrClusters[clusterIndex]);
							}

							if (mgPhases[phaseIndex].arrBonusCells.length != 0)
							{
								canvasIdStr = 'cvsMainAudit' + phaseIndex.toString();
								elementStr  = 'phaseMainAudit' + phaseIndex.toString();
								doTrigger   = true;

								showAuditSymbs(canvasIdStr, elementStr, mgPhases[phaseIndex].arrGrid, mgPhases[phaseIndex].arrBonusCells);
							}

							r.push('</td>');

							//////////////////////////////////////
							// Main Game Prizes or trigger text //
							//////////////////////////////////////

							var prizeCount = 0;
							var prizeStr   = '';
							var prizeText  = '';

							r.push('<td valign="top" style="padding-bottom:25px">');

							if (mgPhases[phaseIndex].arrClusters.length > 0)
							{
								r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');

								for (clusterIndex = 0; clusterIndex < mgPhases[phaseIndex].arrClusters.length; clusterIndex++)
								{
									symbPrize    = mgPhases[phaseIndex].arrClusters[clusterIndex].strPrize;
									canvasIdStr  = 'cvsMainClusterPrize' + phaseIndex.toString() + '_' + clusterIndex.toString() + symbPrize;
									elementStr   = 'mainClusterPrizeSymb' + phaseIndex.toString() + '_' + clusterIndex.toString() + symbPrize;
									prizeIndex   = symbPrizes.indexOf(symbPrize);
									boxColourStr = prizeColours[prizeIndex];
									prizeCount   = mgPhases[phaseIndex].arrClusters[clusterIndex].arrCells.length;
									prizeText    = symbPrize + prizeCount.toString();
									prizeStr     = convertedPrizeValues[getPrizeNameIndex(prizeNames, prizeText)];

									r.push('<tr class="tablebody">');
									r.push('<td>' + prizeCount.toString() + ' x</td>');
									r.push('<td align="center">');

									showSymb(canvasIdStr, elementStr, boxColourStr, colourBlack, symbPrize);
									
									r.push('</td>');
									r.push('<td>= ' + prizeStr + '</td>');
									r.push('</tr>');
								}

								r.push('</table>');
							}

							if (doTrigger)
							{
								triggerStr = (doFreePlays) ? 'bonusFreePlay' : ((doInstantWin) ? 'bonusInstantWin' : 'bonusLockAndKey' );
								triggerStr = getTranslationByName(triggerStr, translations) + ' ' + getTranslationByName("triggered", translations);

								r.push(triggerStr);
							}

							r.push('</td>');
							r.push('</tr>');
						}

						r.push('</table>');

						//////////////////////
						// Free Plays Bonus //
						//////////////////////

						if (doFreePlays)
						{
							var maxClusters = 0;
							
							doTrigger = false;

							r.push('<p>' + getTranslationByName("bonusFreePlay", translations).toUpperCase() + '</p>');

							for (var freePlayIndex = 0; freePlayIndex < freePlayGames; freePlayIndex++)
							{
								for (var phaseIndex = 0; phaseIndex < fpGames[freePlayIndex].length; phaseIndex++)
								{
									if (fpGames[freePlayIndex][phaseIndex].arrClusters.length > maxClusters)
									{
										maxClusters = fpGames[freePlayIndex][phaseIndex].arrClusters.length;
									}
								}
							}

							for (var freePlayIndex = 0; freePlayIndex < freePlayGames; freePlayIndex++)
							{
								r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');

								for (var phaseIndex = 0; phaseIndex < fpGames[freePlayIndex].length; phaseIndex++)
								{
									//////////////////////////
									// Free Play Phase Info //
									//////////////////////////

									phaseStr = getTranslationByName("phaseNum", translations) + ' ' + (phaseIndex+1).toString() + ' ' + getTranslationByName("phaseOf", translations) + ' ' + fpGames[freePlayIndex].length.toString();

									r.push('<tr class="tablebody">');
									r.push('<td valign="top">' + getTranslationByName("symbP", translations) + ' ' + (freePlayIndex+1).toString() + '<br><br>' + phaseStr + '</td>');

									////////////////////
									// Free Play Grid //
									////////////////////

									canvasIdStr = 'cvsFreePlayGrid' + freePlayIndex.toString() + '_' + phaseIndex.toString();
									elementStr  = 'phaseFreePlayGrid' + freePlayIndex.toString() + '_' + phaseIndex.toString();

									r.push('<td style="padding-left:50px; padding-right:50px; padding-bottom:25px">');

									showGridSymbs(canvasIdStr, elementStr, fpGames[freePlayIndex][phaseIndex].arrGrid);

									r.push('</td>');

									////////////////////////
									// Free Play Clusters //
									////////////////////////

									r.push('<td style="padding-right:50px; padding-bottom:25px">');

									for (clusterIndex = 0; clusterIndex < fpGames[freePlayIndex][phaseIndex].arrClusters.length; clusterIndex++)
									{
										canvasIdStr = 'cvsFreePlayAudit' + freePlayIndex.toString() + '_' + phaseIndex.toString() + '_' + clusterIndex.toString();
										elementStr  = 'phaseFreePlayAudit' + freePlayIndex.toString() + '_' + phaseIndex.toString() + '_' + clusterIndex.toString();

										showAuditSymbs(canvasIdStr, elementStr, fpGames[freePlayIndex][phaseIndex].arrGrid, fpGames[freePlayIndex][phaseIndex].arrClusters[clusterIndex]);
									}

									for (clusterIndex = fpGames[freePlayIndex][phaseIndex].arrClusters.length; clusterIndex < maxClusters; clusterIndex++)
									{
										canvasIdStr = 'cvsFreePlayAudit' + freePlayIndex.toString() + '_' + phaseIndex.toString() + '_' + clusterIndex.toString();

										r.push('<canvas id="' + canvasIdStr + '" width="' + (gridCanvasWidth + 25).toString() + '" height="' + gridCanvasHeight.toString() + '"></canvas>');
									}

									r.push('</td>');

									//////////////////////
									// Free Play Prizes //
									//////////////////////

									r.push('<td valign="top" style="padding-bottom:25px">');

									if (fpGames[freePlayIndex][phaseIndex].arrClusters.length > 0)
									{
										r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');

										for (clusterIndex = 0; clusterIndex < fpGames[freePlayIndex][phaseIndex].arrClusters.length; clusterIndex++)
										{
											symbPrize    = fpGames[freePlayIndex][phaseIndex].arrClusters[clusterIndex].strPrize;
											canvasIdStr  = 'cvsFreePlayClusterPrize' + freePlayIndex.toString() + '_' + clusterIndex.toString() + symbPrize;
											elementStr   = 'freeplayClusterPrizeSymb' + freePlayIndex.toString() + '_' + clusterIndex.toString() + symbPrize;
											prizeIndex   = symbPrizes.indexOf(symbPrize);
											boxColourStr = prizeColours[prizeIndex];
											prizeCount   = fpGames[freePlayIndex][phaseIndex].arrClusters[clusterIndex].arrCells.length;
											prizeText    = symbPrize + prizeCount.toString();
											prizeStr     = convertedPrizeValues[getPrizeNameIndex(prizeNames, prizeText)];

											r.push('<tr class="tablebody">');
											r.push('<td>' + prizeCount.toString() + ' x</td>');
											r.push('<td align="center">');

											showSymb(canvasIdStr, elementStr, boxColourStr, colourBlack, symbPrize);
									
											r.push('</td>');
											r.push('<td>= ' + prizeStr + '</td>');
											r.push('</tr>');
										}

										r.push('</table>');
									}

									r.push('</td>');
									r.push('</tr>');
								}

								r.push('</table>');
							}
						}

						////////////////////////
						// Instant Wins Bonus //
						////////////////////////

						if (doInstantWin)
						{
							r.push('<p>' + getTranslationByName("bonusInstantWin", translations).toUpperCase() + '</p>');

							r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
							r.push('<tr class="tablebody">');
							r.push('<td align="center">');

							canvasIdStr = 'cvsInstantWinPrize';
							elementStr  = 'iwPrizeSymb';
							prizeText   = symbInstantWin + (scenarioInstantWins[0]).toString();
							prizeStr    = convertedPrizeValues[getPrizeNameIndex(prizeNames, prizeText)];

							showSymb(canvasIdStr, elementStr, colourGreen, colourBlack, symbInstantWin);

							r.push('</td>');
							r.push('<td>' + getTranslationByName("prizeLevel", translations) + ' ' + (scenarioInstantWins[0]).toString() + ' = ' + prizeStr + '</td>');
							r.push('</tr>');
							r.push('</table>');
						}

						////////////////////////
						// Lock And Key Bonus //
						////////////////////////

						function showRoundForPlayer(A_strCanvasId, A_strCanvasElement, A_strData)
						{
							var canvasCtxStr = 'canvasContext' + A_strCanvasElement;
							var cellY        = 0;
							var hitStr       = '';
							var playerActive = (playerIndex + playerLoop) % 2;
							var symbIndex    = -1;

							r.push('<canvas id="' + A_strCanvasId + '" width="' + gridCanvasWidth.toString() + '" height="' + gridCanvasHeight.toString() + '"></canvas>');
							r.push('<script>');
							r.push('var ' + A_strCanvasElement + ' = document.getElementById("' + A_strCanvasId + '");');
							r.push('var ' + canvasCtxStr + ' = ' + A_strCanvasElement + '.getContext("2d");');
							r.push(canvasCtxStr + '.textAlign = "center";');
							r.push(canvasCtxStr + '.textBaseline = "middle";');

							for (var gridRow = 0; gridRow < battleTurns; gridRow++)
							{
								symbIndex = gridRow * 2 + playerActive;
								hitStr    = (A_strData.length > symbIndex) ? A_strData[symbIndex] : '';
								cellY     = gridRow * cellSize;

								playerScores[playerLoop] += (hitStr == '') ? 0 : parseInt(hitStr,10);

								r.push(canvasCtxStr + '.font = "bold 14px Arial";');
								r.push(canvasCtxStr + '.strokeRect(' + (cellMargin + 0.5).toString() + ', ' + (cellY + cellMargin + 0.5).toString() + ', ' + cellSize.toString() + ', ' + cellSize.toString() + ');');
								r.push(canvasCtxStr + '.fillStyle = "' + colourWhite + '";');
								r.push(canvasCtxStr + '.fillRect(' + (cellMargin + 1.5).toString() + ', ' + (cellY + cellMargin + 1.5).toString() + ', ' + (cellSize - 2).toString() + ', ' + (cellSize - 2).toString() + ');');
								r.push(canvasCtxStr + '.fillStyle = "' + colourBlack + '";');
								r.push(canvasCtxStr + '.fillText("' + hitStr + '", ' + cellTextX.toString() + ', ' + (cellY + cellTextY).toString() + ');');
							}

							r.push('</script>');
						}

						if (doLAKBonus)
						{
							const playerText = [getTranslationByName('battlePlayer1', translations), getTranslationByName('battlePlayer2', translations)];

							var battleEnds    = '';
							var playerIndex   = 0;
							var playerScores  = [0,0];
							var playerStr     = '';
							var prizeLevel    = 0;
							var roundText     = '';
							var roundWinner   = -1;
							var roundWinScore = 0;
							var totalScores   = [0,0];

							gridCanvasHeight = battleTurns * cellSize + 2 * cellMargin;
							gridCanvasWidth  = cellSize + 2 * cellMargin;

							r.push('<p>' + getTranslationByName("bonusLockAndKey", translations).toUpperCase() + '</p>');

							r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');

							for (battleRoundIndex = 0; battleRoundIndex < battleRounds; battleRoundIndex++)
							{
								///////////////////////
								// Battle Round Info //
								///////////////////////

								phaseStr  = getTranslationByName("battleRoundNum", translations) + ' ' + (battleRoundIndex+1).toString() + ' ' + getTranslationByName("phaseOf", translations) + ' ' + battleRounds.toString();
								playerStr = playerText[playerIndex] + ' ' + getTranslationByName("battleGoesFirst", translations);

								r.push('<tr class="tablebody">');
								r.push('<td valign="top">' + phaseStr + '<br><br>' + playerStr + '</td>');

								////////////////
								// Round Hits //
								////////////////

								r.push('<td valign="top" style="padding-left:50px; padding-right:50px; padding-bottom:25px">');

								r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
								r.push('<tr class="tablebody">');

								playerScores = [0,0];

								for (var playerLoop = 0; playerLoop < 2; playerLoop++)
								{
									r.push('<td align="center" style="padding-right:20px">' + playerText[playerLoop] + '<br>');

									canvasIdStr  = 'cvsBonusRoundPlayer' + battleRoundIndex.toString() + '_' + playerLoop.toString();
									elementStr   = 'bonusRoundPlayer' + battleRoundIndex.toString() + '_' + playerLoop.toString();

									showRoundForPlayer(canvasIdStr, elementStr, scenarioLAKBonus[battleRoundIndex]);

									r.push('<br><br>');

									canvasIdStr  = 'cvsBonusRoundHits' + battleRoundIndex.toString() + '_' + playerLoop.toString();
									elementStr   = 'bonusRoundHits' + battleRoundIndex.toString() + '_' + playerLoop.toString();
									boxColourStr = (playerScores[playerLoop] == 6) ? colourLime : colourWhite;

									showSymb(canvasIdStr, elementStr, boxColourStr, colourBlack, playerScores[playerLoop]);

									r.push('</td>');
								}

								r.push('</tr>');
								r.push('</table>');
								r.push('</td>');

								////////////////////////
								// Battle Description //
								////////////////////////

								roundWinner   = (playerScores[0] == 6) ? 0 : 1;
								roundWinScore = 6 - playerScores[1-roundWinner];

								totalScores[roundWinner] += roundWinScore;

								roundText = playerText[roundWinner] + ' ' + getTranslationByName("battleWinsTheRound", translations) +
											'<br><br>' + playerText[1-roundWinner] + ' ' + getTranslationByName("battleLoserMade", translations) + ' ' + playerScores[1-roundWinner] + ' ' +
											getTranslationByName("battleLoserHits", translations) +
											'<br>' + getTranslationByName("battleSo", translations) + ' ' + playerText[roundWinner] + ' ' + getTranslationByName("battleWinsWith", translations) + ' ' +
											roundWinScore.toString() + ' ' + getTranslationByName("battleEnergyRemaining", translations) +
											'<br><br>' + getTranslationByName("battleSoTheScoreIs", translations) + ' [' + totalScores[0].toString() + ' - ' + totalScores[1].toString() + ']';

								r.push('<td valign="top">' + roundText + '</td>');

								playerIndex = (playerIndex == 0) ? 1 : 0;
								
								r.push('</tr>');
							}

							r.push('</table>');

							////////////////////////
							// Battle Bonus Prize //
							////////////////////////

							canvasIdStr = 'cvsBonusPrize';
							elementStr  = 'bonusPrizeSymb';
							prizeLevel  = totalScores[0] - 2;
							prizeText   = symbKey + prizeLevel.toString();
							prizeStr    = convertedPrizeValues[getPrizeNameIndex(prizeNames, prizeText)];

							battleEnds  = getTranslationByName("bonusLockAndKey", translations) + ' ' + getTranslationByName("battleEndsWith", translations) + ' ' + playerText[0] + ' ' +
										  getTranslationByName("battleHavingScored", translations) + ' ' + totalScores[0].toString() + ' ' + getTranslationByName("battleSoWins", translations);

							r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
							r.push('<tr class="tablebody">');
							r.push('<td>' + battleEnds + '</td>');
							r.push('<td align="center">');

							showSymb(canvasIdStr, elementStr, colourNavy, colourYellow, symbKey);

							r.push('</td>');
							r.push('<td>' + getTranslationByName("prizeLevel", translations) + ' ' + prizeLevel.toString() + ' = ' + prizeStr + '</td>');
							r.push('</tr>');
							r.push('</table>');
						}						

						r.push('<p>&nbsp;</p>');

						////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
						// !DEBUG OUTPUT TABLE
						if(debugFlag)
						{
							// DEBUG TABLE
							//////////////////////////////////////
							r.push('<table border="0" cellpadding="2" cellspacing="1" width="100%" class="gameDetailsTable" style="table-layout:fixed">');
							for(var idx = 0; idx < debugFeed.length; ++idx)
 							{
								if(debugFeed[idx] == "")
									continue;
								r.push('<tr>');
 								r.push('<td class="tablebody">');
								r.push(debugFeed[idx]);
 								r.push('</td>');
	 							r.push('</tr>');
							}
							r.push('</table>');
						}
						return r.join('');
					}

					// Input: A list of Price Points and the available Prize Structures for the game as well as the wagered price point
					// Output: A string of the specific strPrize structure for the wagered price point
					function retrievePrizeTable(pricePoints, prizeStructures, wageredPricePoint)
					{
						var pricePointList = pricePoints.split(",");
						var prizeStructStrings = prizeStructures.split("|");

						for(var i = 0; i < pricePoints.length; ++i)
						{
							if(wageredPricePoint == pricePointList[i])
							{
								return prizeStructStrings[i];
							}
						}

						return "";
					}

					// Input: Json document string containing 'scenario' at root level.
					// Output: Scenario value.
					function getScenario(jsonContext)
					{
						// Parse json and retrieve scenario string.
						var jsObj = JSON.parse(jsonContext);
						var scenario = jsObj.scenario;

						// Trim null from scenario string.
						scenario = scenario.replace(/\0/g, '');

						return scenario;
					}

					// Input: Json document string containing 'amount' at root level.
					// Output: Price Point value.
					function getPricePoint(jsonContext)
					{
						// Parse json and retrieve price point amount
						var jsObj = JSON.parse(jsonContext);
						var pricePoint = jsObj.amount;

						return pricePoint;
					}

					function getMainGameData(scenario)
					{
						return scenario.split("|")[0];
					}

					function getFreePlaysData(scenario)
					{
						var scenarioParts = scenario.split("|").length;

						if (scenarioParts == 6)
						{
							return scenario.split("|").slice(1,4);
						}

						return "";
					}

					function getInstantWinsData(scenario)
					{
						var scenarioParts = scenario.split("|").length;
						var scenarioIndex = (scenarioParts == 6) ? 4 : 1;

						return scenario.split("|")[scenarioIndex];
					}

					function getLAKBonusData(scenario)
					{
						var scenarioParts = scenario.split("|").length;
						var scenarioIndex = (scenarioParts == 6) ? 5 : 2;

						return scenario.split("|")[scenarioIndex].split(",");
					}

					// Input: "A,B,C,D,..." and "A"
					// Output: index number
					function getPrizeNameIndex(prizeNames, currPrize)
					{
						for(var i = 0; i < prizeNames.length; ++i)
						{
							if(prizeNames[i] == currPrize)
							{
								return i;
							}
						}
					}

					////////////////////////////////////////////////////////////////////////////////////////
					function registerDebugText(debugText)
					{
						debugFeed.push(debugText);
					}

					/////////////////////////////////////////////////////////////////////////////////////////
					function getTranslationByName(keyName, translationNodeSet)
					{
						var index = 1;
						while(index < translationNodeSet.item(0).getChildNodes().getLength())
						{
							var childNode = translationNodeSet.item(0).getChildNodes().item(index);
							
							if(childNode.name == "phrase" && childNode.getAttribute("key") == keyName)
							{
								registerDebugText("Child Node: " + childNode.name);
								return childNode.getAttribute("value");
							}
							
							index += 1;
						}
					}

					// Grab Wager Type
					// @param jsonContext String JSON results to parse and display.
					// @param translation Set of Translations for the game.
					function getType(jsonContext, translations)
					{
						// Parse json and retrieve wagerType string.
						var jsObj = JSON.parse(jsonContext);
						var wagerType = jsObj.wagerType;

						return getTranslationByName(wagerType, translations);
					}
					]]>
				</lxslt:script>
			</lxslt:component>

			<x:template match="root" mode="last">
				<table border="0" cellpadding="1" cellspacing="1" width="100%" class="gameDetailsTable">
					<tr>
						<td valign="top" class="subheader">
							<x:value-of select="//translation/phrase[@key='totalWager']/@value" />
							<x:value-of select="': '" />
							<x:call-template name="Utils.ApplyConversionByLocale">
								<x:with-param name="multi" select="/output/denom/percredit" />
								<x:with-param name="value" select="//ResultData/WagerOutcome[@name='Game.Total']/@amount" />
								<x:with-param name="code" select="/output/denom/currencycode" />
								<x:with-param name="locale" select="//translation/@language" />
							</x:call-template>
						</td>
					</tr>
					<tr>
						<td valign="top" class="subheader">
							<x:value-of select="//translation/phrase[@key='totalWins']/@value" />
							<x:value-of select="': '" />
							<x:call-template name="Utils.ApplyConversionByLocale">
								<x:with-param name="multi" select="/output/denom/percredit" />
								<x:with-param name="value" select="//ResultData/PrizeOutcome[@name='Game.Total']/@totalPay" />
								<x:with-param name="code" select="/output/denom/currencycode" />
								<x:with-param name="locale" select="//translation/@language" />
							</x:call-template>
						</td>
					</tr>
				</table>
			</x:template>

			<!-- TEMPLATE Match: digested/game -->
			<x:template match="//Outcome">
				<x:if test="OutcomeDetail/Stage = 'Scenario'">
					<x:call-template name="Scenario.Detail" />
				</x:if>
			</x:template>

			<!-- TEMPLATE Name: Scenario.Detail (base game) -->
			<x:template name="Scenario.Detail">
				<x:variable name="odeResponseJson" select="string(//ResultData/JSONOutcome[@name='ODEResponse']/text())" />
				<x:variable name="translations" select="lxslt:nodeset(//translation)" />
				<x:variable name="wageredPricePoint" select="string(//ResultData/WagerOutcome[@name='Game.Total']/@amount)" />
				<x:variable name="prizeTable" select="lxslt:nodeset(//lottery)" />

				<table border="0" cellpadding="0" cellspacing="0" width="100%" class="gameDetailsTable">
					<tr>
						<td class="tablebold" background="">
							<x:value-of select="//translation/phrase[@key='wagerType']/@value" />
							<x:value-of select="': '" />
							<x:value-of select="my-ext:getType($odeResponseJson, $translations)" disable-output-escaping="yes" />
						</td>
					</tr>
					<tr>
						<td class="tablebold" background="">
							<x:value-of select="//translation/phrase[@key='transactionId']/@value" />
							<x:value-of select="': '" />
							<x:value-of select="OutcomeDetail/RngTxnId" />
						</td>
					</tr>
				</table>
				<br />			
				
				<x:variable name="convertedPrizeValues">
					<x:apply-templates select="//lottery/prizetable/prize" mode="PrizeValue"/>
				</x:variable>

				<x:variable name="prizeNames">
					<x:apply-templates select="//lottery/prizetable/description" mode="PrizeDescriptions"/>
				</x:variable>


				<x:value-of select="my-ext:formatJson($odeResponseJson, $translations, $prizeTable, string($convertedPrizeValues), string($prizeNames))" disable-output-escaping="yes" />
			</x:template>

			<x:template match="prize" mode="PrizeValue">
					<x:text>|</x:text>
					<x:call-template name="Utils.ApplyConversionByLocale">
						<x:with-param name="multi" select="/output/denom/percredit" />
					<x:with-param name="value" select="text()" />
						<x:with-param name="code" select="/output/denom/currencycode" />
						<x:with-param name="locale" select="//translation/@language" />
					</x:call-template>
			</x:template>
			<x:template match="description" mode="PrizeDescriptions">
				<x:text>,</x:text>
				<x:value-of select="text()" />
			</x:template>

			<x:template match="text()" />
		</x:stylesheet>
	</xsl:template>

	<xsl:template name="TemplatesForResultXSL">
		<x:template match="@aClickCount">
			<clickcount>
				<x:value-of select="." />
			</clickcount>
		</x:template>
		<x:template match="*|@*|text()">
			<x:apply-templates />
		</x:template>
	</xsl:template>
</xsl:stylesheet>
