#1. UAT-uri poligon
#filtrare cîmpuri din fișierul ANCPI și scriere fișier .prj
ogr2ogr  -a_srs "EPSG:3844" -f "SQLite" uat.db /home/earth/data/vector/limite_administrative/Administrative_unit_3rd_Order.shp

#încărcare tabel regiuni de dezvoltare în SQLITE
csvsql --db sqlite:///uat.db --insert /home/earth/data/tabel/siruta_zone.csv

#încărcare tabel UAT-uri în SQLITE
csvsql --db sqlite:///uat.db --insert /home/earth/data/tabel/siruta_judete.csv

#încărcare tabele populație
csvsql --db sqlite:///uat.db --insert /home/earth/data/tabel/pop_uat_01_01_2011.csv
csvsql --db sqlite:///uat.db --insert /home/earth/data/tabel/pop_uat_01_01_2012.csv
csvsql --db sqlite:///uat.db --insert /home/earth/data/tabel/pop_uat_01_01_2013.csv
csvsql --db sqlite:///uat.db --insert /home/earth/data/tabel/pop_uat_01_01_2014.csv
csvsql --db sqlite:///uat.db --insert /home/earth/data/tabel/pop_uat_01_01_2015.csv

#conversie MDB în CSV
mdb-export /home/earth/data/tabel/sir_diacritic.mdb sir_diacritic > sir_diacritic.csv

#formatare CSV: se elimină cîmpurile nerelevante (FSJ, FS2, FS3, fictiv); se formatează cîmpurile de tip text ca "lowercase"; se convertesc cîmpurile SIRUTA, CODP și SIRSUP din notarea științifică în format integer
awk -F, 'BEGIN{printf("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n","siruta","denloc","codp","jud","sirsup","tip","niv","med","regiune","fsl", "rang")} NR>1{printf("%.0f,%s,%.0f,%d,%.0f,%d,%d,%s,%d,%s,%s\n",$1,tolower($2),$3,$4,$5,$6,$7,$8,$9,$13,$14)}' sir_diacritic.csv > siruta.csv

#înlocuire diacritice incorecte ("ș" și "ț" din sedilă în virguă; se corectează "ă")
sed -i -e 's/ş/ș/g' -e 's/ţ/ț/g' -e 's/ã/ă/g' siruta.csv

#conversie cîmpuri de tip text din "lowercase" în "titlecase" - este exceptat primul rînd, cel cu numele de coloane
sed -i '2,$s/.*/\L&/; 2,$s/[a-z]*/\u&/g' siruta.csv

#înlocuire prepoziții folosite în numele de localități din "titlecase" înapoi în "lowercase"
sed -i -e 's/ De / de /g' -e 's/ Din / din /g' -e 's/ La / la /g' -e 's/ Pe / pe /g' -e 's/ Cu / cu /g' -e 's/ Lui / lui /g' -e 's/ Cel / cel /g' -e 's/ Sub / sub /g' -e 's/ In / în /g' -e 's/ ii/ II/g' -e 's/Municipiul //g' -e 's/Oraș //g' siruta.csv

#încărcare tabel SIRUTA în SQLITE
csvsql --db sqlite:///uat.db --insert siruta.csv

ogr2ogr -f "SQLite" -append -dsco SPATIALITE=YES -lco LAUNDER=NO -a_srs EPSG:3844 -nln ro_uat_poligon -sql "SELECT a.natCode, b.denloc AS name, a.natLevName AS natLevName, c.jud AS countyId, c.siruta AS countyCode, c.denj AS county, c.mnemonic AS countyMn, d.zona  AS regionId, d.siruta  AS regionCode, d.denzona AS region, e.pop_tot_2011 AS pop2011, f.pop_tot_2012 AS pop2012, g.pop_tot_2013 AS pop2013, h.pop_tot_2014 AS pop2014, i.pop_tot_2015 AS pop2015, b.fsl AS sortCode, a.beginvers AS version, a.GEOMETRY FROM Administrative_unit_3rd_Order AS a LEFT JOIN siruta AS b ON (a.natcode = b.siruta) LEFT JOIN siruta_judete AS c ON (c.jud=b.jud) LEFT JOIN siruta_zone AS d ON (c.zona=d.zona) LEFT JOIN pop_uat_01_01_2011 AS e ON (e.siruta=a.natCode) LEFT JOIN pop_uat_01_01_2012 AS f ON (f.siruta=a.natCode) LEFT JOIN pop_uat_01_01_2013 AS g ON (g.siruta=a.natCode) LEFT JOIN pop_uat_01_01_2014 AS h ON (h.siruta=a.natCode) LEFT JOIN pop_uat_01_01_2015 AS i ON (i.siruta=a.natCode)" uat.db uat.db

#creare fișiere Esri Shapefile
ogr2ogr  -lco ENCODING=UTF-8 -a_srs EPSG:3844 -sql "SELECT * FROM ro_uat_poligon" ro_uat_poligon.shp uat.db

#arhivare fișiere shp
zip ro_uat_poligon.zip ro_uat_poligon.*

#creare versiune GeoPackage
ogr2ogr   -f GPKG -a_srs EPSG:3844 ro_uat_poligon.gpkg ro_uat_poligon.shp

#creare versiune GeoJSON
ogr2ogr  -f GeoJSON -s_srs EPSG:3844 -t_srs EPSG:4326 ro_uat_poligon.geojson ro_uat_poligon.shp

#creare versiune KML
ogr2ogr  -f KML -s_srs EPSG:3844 -t_srs EPSG:4326 -dsco NameField=name ro_uat_poligon.kml ro_uat_poligon.shp

#copiere fișiere în directorul de download
cp -rf ro_uat_poligon.zip ro_uat_poligon.gpkg ro_uat_poligon.geojson ro_uat_poligon.kml /var/www/geospatial/files/vector/limite_administrative/uat

#actualizarea setului de date în baza de date PostGIS
ogr2ogr -f "PostgreSQL" PG:"host=localhost user=user dbname=geospatial password=password" -lco schema=romania -lco overwrite=yes  -lco LAUNDER=NO -nlt MULTIPOLYGON ro_uat_poligon.shp ro_uat_poligon -a_srs EPSG:3844 -skipfailures -overwrite

#actualizarea metadatelor din serviciile de date
curl -u user:password -XPUT -H "Content-type: text/xml" -d "<featureType><abstract>Setul de date cuprinde limitele unităților administrativ teritoriale (geometrie poligon). Actualizare 23.03.2016. Sursa ANCPI.</abstract><enabled>true</enabled></featureType>" http://localhost:8080/geoserver/rest/workspaces/geospatial/datastores/geospatial_romania/featuretypes/ro_uat_poligon


#2. UAT-uri polilinie
ogr2ogr  -append -a_srs "EPSG:3844" -f "SQLite" uat.db /home/earth/data/vector/limite_administrative/Administrative_boundary_3rd_Order.shp


sqlite3 uat.db "CREATE TABLE split_siruta AS SELECT id, substr(localid, 1, instr(localid, '.') - 1) AS leftId, substr(localid, instr(localid, '.') + 1) AS rightId FROM Administrative_boundary_3rd_Order"

ogr2ogr  -f "SQLite" -append -dsco SPATIALITE=YES -lco LAUNDER=NO -a_srs EPSG:3844 -nln ro_uat_polilinie -sql "SELECT a.id, c.name AS leftUat, d.name AS rightUat, b.leftId, b.rightId, a.beginvers AS version, a.GEOMETRY FROM Administrative_boundary_3rd_Order AS a LEFT JOIN split_siruta AS b ON (a.id = b.id) LEFT JOIN ro_uat_poligon AS c ON (b.leftId=c.natCode) LEFT JOIN ro_uat_poligon AS d ON (b.rightId=d.natCode)" uat.db uat.db

#creare fișiere Esri Shapefile
ogr2ogr  -lco ENCODING=UTF-8 -a_srs EPSG:3844 -sql "SELECT * FROM ro_uat_polilinie" ro_uat_polilinie.shp uat.db

#arhivare fișiere shp
zip ro_uat_polilinie.zip ro_uat_polilinie.*

#creare versiune GeoPackage
ogr2ogr   -f GPKG -a_srs EPSG:3844 ro_uat_polilinie.gpkg ro_uat_polilinie.shp

#creare versiune GeoJSON
ogr2ogr  -f GeoJSON -s_srs EPSG:3844 -t_srs EPSG:4326 ro_uat_polilinie.geojson ro_uat_polilinie.shp

#creare versiune KML
ogr2ogr  -f KML -s_srs EPSG:3844 -t_srs EPSG:4326 -dsco NameField=name ro_uat_polilinie.kml ro_uat_polilinie.shp

#actualizarea setului de date în baza de date PostGIS
ogr2ogr -f "PostgreSQL" PG:"host=localhost user=user dbname=geospatial password=password" -lco schema=romania -lco overwrite=yes -lco LAUNDER=NO ro_uat_polilinie.shp ro_uat_polilinie -a_srs EPSG:3844 -skipfailures -overwrite

#copiere fișiere în directorul de download
cp -rf ro_uat_polilinie.zip ro_uat_polilinie.gpkg ro_uat_polilinie.geojson ro_uat_polilinie.kml /var/www/geospatial/files/vector/limite_administrative/uat

#actualizarea metadatelor din serviciile de date
curl -u user:password -XPUT -H "Content-type: text/xml" -d "<featureType><abstract>Setul de date cuprinde limitele unităților administrativ teritoriale (geometrie polilinie). Actualizare 23.03.2016. Sursa ANCPI.</abstract><enabled>true</enabled></featureType>" http://localhost:8080/geoserver/rest/workspaces/geospatial/datastores/geospatial_romania/featuretypes/ro_uat_polilinie

rm ro_uat*.* uat.db sir_diacritic.csv siruta.csv
