#conversie MDB în CSV
mdb-export /home/earth/data/tabel/sir_diacritic.mdb sir_diacritic > sir_diacritic.csv

#formatare CSV: se elimină cîmpurile nerelevante (FSJ, FS2, FS3, fictiv); se formatează cîmpurile de tip text ca "lowercase"; se convertesc cîmpurile SIRUTA, CODP și SIRSUP din notarea științifică în format integer
awk -F, 'BEGIN{printf("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n","siruta","denloc","codp","jud","sirsup","tip","niv","med","regiune","fsl", "rang")} NR>1{printf("%.0f,%s,%.0f,%d,%.0f,%d,%d,%s,%d,%s,%s\n",$1,tolower($2),$3,$4,$5,$6,$7,$8,$9,$13,$14)}' sir_diacritic.csv > siruta.csv

#înlocuire diacritice incorecte ("ș" și "ț" din sedilă în virguă; se corectează "ă")
sed -i -e 's/ş/ș/g' -e 's/ţ/ț/g' -e 's/ã/ă/g' siruta.csv

#conversie cîmpuri de tip text din "lowercase" în "titlecase" - este exceptat primul rînd, cel cu numele de coloane
sed -i '2,$s/.*/\L&/; 2,$s/[a-z]*/\u&/g' siruta.csv

#înlocuire prepoziții folosite în numele de localități din "titlecase" înapoi în "lowercase"
sed -i -e 's/ De / de /g' -e 's/ Din / din /g' -e 's/ La / la /g' -e 's/ Pe / pe /g' -e 's/ Cu / cu /g' -e 's/ Lui / lui /g' -e 's/ Cel / cel /g' -e 's/ Sub / sub /g' -e 's/ In / în /g' -e 's/ ii/ II/g' -e 's/Municipiul //g' -e 's/Oraș //g' -e 's/ Sectorul 1//g' siruta.csv

#încărcare tabel SIRUTA în SQLITE
csvsql --db sqlite:///localitati.db --insert siruta.csv

#încărcare tabel regiuni de dezvoltare în SQLITE
csvsql --db sqlite:///localitati.db --insert /home/earth/data/tabel/siruta_zone.csv

#încărcare tabel UAT-uri în SQLITE
csvsql --db sqlite:///localitati.db --insert /home/earth/data/tabel/siruta_judete.csv

#încărcare fișier shapefile cu localitățile în SQLITE
ogr2ogr -append -f "SQLite" -lco LAUNDER=NO localitati.db /home/earth/data/vector/localitati/ro_localitati_2014.shp

#încărcare fișier shapefile cu localitățile "fantomă"" în SQLITE
ogr2ogr -append -f "SQLite" localitati.db /home/earth/data/vector/localitati/localitati_fantoma_3844.shp

#conversie cîmp rang în "uppercase"
sqlite3 localitati.db "UPDATE siruta SET rang = UPPER(rang)"

#creare tabel doar cu localitățile propriu-zise
sqlite3 localitati.db "CREATE TABLE siruta_localitati AS SELECT * FROM siruta WHERE niv = 3"

#
ogr2ogr -f "SQLite" -append -dsco SPATIALITE=YES -lco LAUNDER=NO -a_srs EPSG:3844 -nln ro_localitati_punct_intermediar -sql "SELECT a.siruta AS natCode, a.denloc AS name, a.jud AS countyId, b.siruta AS countyCode, b.denj AS county, b.mnemonic AS countyMn, c.zona  AS regionId, c.siruta  AS regionCode, c.denzona AS region, d.pop2002 AS pop2002, a.rang AS rank, a.tip AS type, a.med AS enviroType, a.codp AS postalCode, d.old_postal AS oldPostal, a.fsl AS sortCode, a.sirsup AS supCode, d.geometry FROM ro_localitati_2014 AS d LEFT JOIN siruta AS a ON (d.siruta = a.siruta) LEFT JOIN siruta_zone AS c ON (d.region_id=c.zona) LEFT JOIN siruta_judete b ON (d.county_id=b.jud)" localitati.db localitati.db

ogr2ogr -f "SQLite" -append -dsco SPATIALITE=YES -lco LAUNDER=NO -a_srs EPSG:3844 -nln ro_localitati_punct -sql "SELECT a.*, b.denloc AS nameSup FROM ro_localitati_punct_intermediar AS a LEFT JOIN siruta AS b ON (a.supCode = b.siruta)" localitati.db localitati.db

#creare cîmp pentru marcarea localităților "fantomă"
sqlite3 localitati.db "ALTER TABLE ro_localitati_punct ADD COLUMN ghost INTEGER default 0"

#
sqlite3 localitati.db "UPDATE ro_localitati_punct SET ghost = 1 WHERE ro_localitati_punct.natCode = (SELECT localitati_fantoma_3844.siruta FROM localitati_fantoma_3844 WHERE localitati_fantoma_3844.siruta = ro_localitati_punct.natCode)"

#creare fișiere Esri Shapefile
ogr2ogr -lco ENCODING=UTF-8 -lco LAUNDER=NO -a_srs EPSG:3844 -sql "SELECT * FROM ro_localitati_punct" ro_localitati_punct.shp localitati.db

#arhivare fișiere shp
zip ro_localitati_punct.zip ro_localitati_punct.*

#creare versiune GeoPackage
ogr2ogr  -f GPKG -a_srs EPSG:3844 ro_localitati_punct.gpkg ro_localitati_punct.shp

#creare versiune GeoJSON
ogr2ogr -f GeoJSON -s_srs EPSG:3844 -t_srs EPSG:4326 ro_localitati_punct.geojson ro_localitati_punct.shp

#creare versiune KML
ogr2ogr -f KML -s_srs EPSG:3844 -t_srs EPSG:4326 -dsco NameField=name ro_localitati_punct.kml ro_localitati_punct.shp

#creare versiune CSV
ogr2ogr -f CSV -s_srs EPSG:3844 -t_srs EPSG:4326 -lco GEOMETRY=AS_XY ro_localitati_punct.csv ro_localitati_punct.shp

#actualizarea setului de date în baza de date PostGIS
ogr2ogr -f "PostgreSQL" PG:"host=localhost user=user dbname=geospatial password=password" -lco schema=romania -lco overwrite=yes -lco LAUNDER=NO ro_localitati_punct.shp ro_localitati_punct -a_srs EPSG:3844 -skipfailures -overwrite

#actualizarea metadatelor din serviciile de date
curl -u user:password -XPUT -H "Content-type: text/xml" -d "<featureType><abstract>Setul de date cuprinde localitățile din România (geometrie punct). Actualizare decembrie 2015. Sursa INS.</abstract><enabled>true</enabled></featureType>" http://localhost:8080/geoserver/rest/workspaces/geospatial/datastores/geospatial_romania/featuretypes/ro_localitati_punct

#copiere fișiere în directorul de download
cp -rf ro_localitati_punct.zip ro_localitati_punct.gpkg ro_localitati_punct.geojson ro_localitati_punct.kml ro_localitati_punct.csv /var/www/geospatial/files/vector/localitati

rm ro_localitati*.* localitati.db sir_diacritic.csv siruta.csv
