import QtQuick
import QtQuick.Controls

import org.qfield
import org.qgis
import Theme

import "qrc:/qml" as QFieldItems

Item {
  id: plugin

  property var mainWindow: iface.mainWindow()
  property var positionSource: iface.findItemByObjectName('positionSource')
  property var dashBoard: iface.findItemByObjectName('dashBoard')
  property var overlayFeatureFormDrawer: iface.findItemByObjectName('overlayFeatureFormDrawer')

  Component.onCompleted: {
    iface.addItemToPluginsToolbar(snapButton)
  }

  Loader {
    id: cameraLoader
    active: false
    sourceComponent: Component {
      id: cameraComponent
    
      QFieldItems.QFieldCamera {
        id: qfieldCamera
        visible: false
    
        Component.onCompleted: {
          open()
        }
    
        onFinished: (path) => {
          close()
          snap(path)
        }
    
        onCanceled: {
          close()
        }
    
        onClosed: {
          cameraLoader.active = false
        }
      }
    }
  }

  QfToolButton {
    id: snapButton
    bgcolor: Theme.darkGray
    iconSource: Theme.getThemeVectorIcon('ic_camera_photo_black_24dp')
    iconColor: Theme.mainColor
    round: true

    onClicked: {
      dashBoard.ensureEditableLayerSelected()

      if (!positionSource.active || !positionSource.positionInformation.latitudeValid || !positionSource.positionInformation.longitudeValid) {
        mainWindow.displayToast(qsTr('Snap requires positioning to be active and returning a valid position'))
        //return
      }
      
      if (dashBoard.activeLayer.geometryType() != Qgis.GeometryType.Point) {
        mainWindow.displayToast(qsTr('Snap requires the active vector layer to be a point geometry'))
        return
      }
      
      let fieldNames = dashBoard.activeLayer.fields.names
      if (fieldNames.indexOf('photo') == -1 && fieldNames.indexOf('picture') == -1) {
        mainWindow.displayToast(qsTr('Snap requires the active vector layer to contain a field named \'photo\' or \'picture\''))
        return
      }

      cameraLoader.active = true
    }
  }

  function snap(path) {
    console.log('Snap ' + path)
    let today = new Date()
    let relativePath = 'DCIM/' + today.getFullYear()
                               + (today.getMonth() +1 ).toString().padStart(2,0)
                               + today.getDate().toString().padStart(2,0)
                               + today.getHours().toString().padStart(2,0)
                               + today.getMinutes().toString().padStart(2,0)
                               + today.getSeconds().toString().padStart(2,0)
                               + '.' + FileUtils.fileSuffix(path)
    platformUtilities.renameFile(path, qgisProject.homePath + '/' + relativePath)
    
    let pos = positionSource.projectedPosition
    let wkt = 'POINT(' + pos.x + ' ' + pos.y + ')'
    
    let geometry = GeometryUtils.createGeometryFromWkt(wkt)
    let feature = FeatureUtils.createBlankFeature(dashBoard.activeLayer.fields, geometry)
        
    let fieldNames = feature.fields.names
    if (fieldNames.indexOf('photo') > -1) {
      feature.setAttribute(fieldNames.indexOf('photo'), relativePath)
    } else if (fieldNames.indexOf('picture') > -1) {
      feature.setAttribute(fieldNames.indexOf('picture'), relativePath)
    }

    overlayFeatureFormDrawer.featureModel.feature = feature
    overlayFeatureFormDrawer.featureModel.resetAttributes(true)
    overlayFeatureFormDrawer.state = 'Add'
    overlayFeatureFormDrawer.open()
    identify(qgisProject.homePath + '/' + relativePath)
  }
  

  function identify(filePath) {
    console.log('Identify ' + filePath);

    const content = readTextFile(filePath);
    console.log(content);

     // Doc https://my.plantnet.org/doc/openapi
    const PROJECT = 'all'; // try 'weurope' or 'canada'
    const API_URL = 'https://my-api.plantnet.org/v2/identify/' + PROJECT;
    const API_KEY = '2b10okfSmtCS1mk7g9iGu0T0e'; // secret

    mainWindow.displayToast(filePath);

    // Read image file
    const image = new File(qgisProject.homePath + '/' + relativePath);

    // print the image size to the console
    log.console(image.size);

    // Add URL parameters
    const url = new URL(API_URL);
    url.searchParams.append('include-related-images', 'false'); // try false
    url.searchParams.append('lang', 'fr'); 
    url.searchParams.append('api-key', API_KEY);

    // Send request
    fetch(url.toString(), {
        method: 'POST',
        body: image,
    })
    .then((response) => {
        if (response.ok) {
            response.json()
            .then((r) => {
                mainWindow.displayToast(JSON.stringify(r));
            })
            .catch(console.error);
        } else {
            mainWindow.displayToast(resp)
        }
    })
    .catch((error) => {
        mainWindow.displayToast(error);
    });
  }

  function request(filePath) {
    const PROJECT = 'all'; // try 'weurope' or 'canada'
    const API_URL = 'https://my-api.plantnet.org/v2/identify/' + PROJECT;
    const API_KEY = '2b10okfSmtCS1mk7g9iGu0T0e'; // secret

    let request = new XMLHttpRequest();
    request.onreadystatechange = function() {
        if(request.readyState === XMLHttpRequest.DONE) {
            mainWindow.displayToast(request.response);
        }
        else {
            mainWindow.displayToast('Error: ' + request.status);
        }
    }
    request.open("POST", API_URL);
    request.setRequestHeader('User-Agent', 'FAKE-USER-AGENT');
    request.send(filePath);
  }


 function readTextFile(fileUrl){
    console.log("inside readTextFile");
    var xhr = new XMLHttpRequest;
    xhr.open("GET", fileUrl); // set Method and File
    xhr.onreadystatechange = function () {
        console.log("inside onreadystatechange");
        if(xhr.readyState === XMLHttpRequest.DONE){ // if request_status == DONE
            var response = xhr.responseText;

            console.log(response);
           // Your Code
        }
    }
    xhr.send(); // begin the request
  }  
}