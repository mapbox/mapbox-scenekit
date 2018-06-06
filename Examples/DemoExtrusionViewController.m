//
//  DemoExtrusionViewController.m
//  Examples
//
//  Created by Avi Cieplinski on 6/5/18.
//  Copyright © 2018 MapBox. All rights reserved.
//

#import <Mapbox/Mapbox.h>
#import <SceneKit/SceneKit.h>

#import "Examples-Swift.h"

#import <MapboxSceneKit/MapboxSceneKit-Swift.h>

#import "DemoExtrusionViewController.h"

@interface DemoExtrusionViewController () <MGLMapViewDelegate>

@property (nonatomic) MGLMapView *mapView;
@property (nonatomic) MBTerrainDemoScene *terrainDemoScene;
@property (nonatomic) MBTerrainNode *terrainNode;

@property (nonatomic) BOOL isAnimating;

@end

@implementation DemoExtrusionViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor colorWithRed:21.0/255.0 green:37.0/255.0 blue:54.0/255.0 alpha:1];
    _mapView = [[MGLMapView alloc] initWithFrame:CGRectMake(0, CGRectGetHeight(self.view.bounds) / 2.0, CGRectGetWidth(self.view.bounds), CGRectGetHeight(self.view.bounds) / 2.0)];
    _mapView.allowsRotating = NO;
    self.mapView.delegate = self;
    [self.view addSubview:self.mapView];
    self.mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.mapView setCenterCoordinate:CLLocationCoordinate2DMake(37.747706422053454, -122.45031891542874)
                            zoomLevel:13
                             animated:NO];
    
    _sceneView.frame = CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), CGRectGetHeight(self.view.bounds) / 2.0);
    _sceneView.userInteractionEnabled = YES;
    _sceneView.multipleTouchEnabled = YES;
    _sceneView.allowsCameraControl = YES;
    [self.view insertSubview:_sceneView belowSubview:self.mapView];
    
    _terrainDemoScene = [[MBTerrainDemoScene alloc] init];
    _terrainDemoScene.background.contents = [UIColor clearColor];
    _terrainDemoScene.floorColor = [UIColor clearColor];
    _terrainDemoScene.floorReflectivity = 0;
    _sceneView.scene = _terrainDemoScene;
    
    _sceneView.backgroundColor = [UIColor clearColor];
    _sceneView.pointOfView = _terrainDemoScene.cameraNode;
    _sceneView.defaultCameraController.pointOfView = _sceneView.pointOfView;
    _sceneView.defaultCameraController.interactionMode = SCNInteractionModeOrbitTurntable;
    _sceneView.defaultCameraController.inertiaEnabled = true;
    _sceneView.showsStatistics = true;
}

#pragma mark SceneKit Setup Methods

- (NSArray<SCNMaterial *> *)_defaultMaterials
{
    SCNMaterial *groundImage = [SCNMaterial new];
    groundImage.diffuse.contents = [UIColor darkGrayColor];
    groundImage.name = @"Ground texture";
    
    SCNMaterial *sideMaterial = [SCNMaterial new];
    sideMaterial.diffuse.contents = [UIColor darkGrayColor];
    sideMaterial.doubleSided = true;
    sideMaterial.name = @"Side";
    
    SCNMaterial *bottomMaterial = [SCNMaterial new];
    bottomMaterial.diffuse.contents = [UIColor blackColor];
    bottomMaterial.name = @"Bottom";
    
    return @[sideMaterial, sideMaterial, sideMaterial, sideMaterial, groundImage, bottomMaterial];
}

- (void)_refreshSceneView
{
    //Set up the terrain and materials
    if (_terrainNode != nil) {
        [_terrainNode removeFromParentNode];
        _terrainNode = nil;
    }
    
    MGLCoordinateBounds coordinateBounds = _mapView.visibleCoordinateBounds;
    _terrainNode = [[MBTerrainNode alloc] initWithMinLat:coordinateBounds.sw.latitude maxLat:coordinateBounds.ne.latitude minLon:coordinateBounds.sw.longitude maxLon:coordinateBounds.ne.longitude];
    
    _terrainNode.position = SCNVector3Make(0, 0, 0);
    _terrainNode.geometry.materials = [self _defaultMaterials];
    [_terrainDemoScene.rootNode addChildNode:_terrainNode];
    
    //Now that we've set up the terrain, lets place the lighting and camera in nicer positions
    SCNVector3 boundingBoxMin = SCNVector3Zero;
    SCNVector3 boundingBoxMax = SCNVector3Zero;
    SCNVector3 boundingSphereCenter = SCNVector3Zero;
    CGFloat boundingSphereRadius = 0.0;
    [_terrainNode getBoundingBoxMin:&boundingBoxMin max:&boundingBoxMax];
    [_terrainNode getBoundingSphereCenter:&boundingSphereCenter radius:&boundingSphereRadius];
    
    _terrainDemoScene.directionalLight.constraints = @[[SCNLookAtConstraint lookAtConstraintWithTarget:_terrainNode]];
    _terrainDemoScene.directionalLight.position = SCNVector3Make(boundingBoxMax.x, boundingSphereCenter.y + 5000, boundingBoxMax.z);
    _terrainDemoScene.cameraNode.position = SCNVector3Make(boundingBoxMax.x * 2, 2000, boundingBoxMax.z * 2.0);
    if (@available(iOS 11.0, *)) {
        [_terrainDemoScene.cameraNode lookAt:_terrainNode.position];
    } else {
        // Fallback on earlier versions
    }
    
    [_terrainNode fetchTerrainHeightsWithMinWallHeight:50.0 enableDynamicShadows:YES progress:^(float progress, NSInteger total) {
    } completion:^{
        NSLog(@"terrain height fetch completed");
    }];
    
    [_terrainNode fetchTerrainTexture:@"mapbox/satellite-v9" zoom:14 progress:^(float progress, NSInteger total) {
    } completion:^(UIImage * _Nullable image) {
        NSLog(@"terrain texture fetch completed");
        self.terrainNode.geometry.materials[4].diffuse.contents = image;
    }];
}

#pragma mark MGLMapViewDelegate

- (void)mapView:(MGLMapView *)mapView regionDidChangeAnimated:(BOOL)animated
{
    // update the SCNSceneView with the updated 2D Map
    [self _refreshSceneView];
}

@end
