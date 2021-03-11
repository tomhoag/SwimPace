//
//  PoolEdge.swift
//  SwimPace
//
//  Created by Tom on 2/22/21.
//

import Foundation
import AVFoundation
import Cocoa

typealias Line = [CGPoint] // line is defined by two points

struct PartialLines {
    
    enum EdgeIndex:CaseIterable {
        case start
        case right
        case turn
        case left
    }

     var start:Line = [CGPoint.zero, CGPoint.zero]
     var right:Line = [CGPoint.zero, CGPoint.zero]
     var turn:Line = [CGPoint.zero, CGPoint.zero]
     var left:Line = [CGPoint.zero, CGPoint.zero]
    
    //func line(index:Int) -> Line {
    func edgeFor(index:EdgeIndex) -> Line {
        switch index {
        case .start:
            return start
        case .right:
            return right
        case .turn:
            return turn
        case .left:
            return left
        }
    }
    
    //mutating func line(_ i:Int, _ line:Line) {
    mutating func updateEdge( _ i:EdgeIndex, _ line:Line) {
        switch i {
        case .start:
            start = line
            break
        case .right:
            self.right = line
            break
        case .turn:
            turn = line
            break
        case .left:
            left = line
            break
        }
    }
    
    func stringFor(_ i:EdgeIndex) -> String {
        switch i {
        case .start:
            return "START"
        case .right:
            return "RIGHT"
        case .turn:
            return "TURN"
        case .left:
            return "LEFT"
        }
    }
}

class PoolEdge {
    
    enum DragPadIndex: CaseIterable {
        case startBegin
        case startEnd
        case rightBegin
        case rightEnd
        case turnBegin
        case turnEnd
        case leftBegin
        case leftEnd
    }
    
    enum PoolCorner: CaseIterable {
        case startLeft
        case startRight
        case turnLeft
        case turnRight
    }
    
    // Scaling factor for increasing the size of the dragPad when it is dragging
    var padScaling:CGFloat = 4
    
    // Zoom level of the image inside the dragpad when it is dragging
    var padMagnify:CGFloat = 2
    
    // The pool corners -- calculated from the pool partial lines
    private var startLeft:CGPoint = .zero
    private var startRight:CGPoint = .zero
    private var turnLeft:CGPoint = .zero
    private var turnRight:CGPoint = .zero
    
    private let dragPadRadius:CGFloat = 20
    
    private var edges = PartialLines()


    init(_ edge:CGRect) {
        startRight = edge.origin // sL
        startLeft = CGPoint(x:edge.origin.x, y:edge.origin.y + edge.size.height) // sR
        turnLeft = CGPoint(x:edge.origin.x + edge.size.width, y: edge.origin.y + edge.size.height) // tL
        turnRight = CGPoint(x:edge.origin.x + edge.size.width, y: edge.origin.y) // tR
        
        let d:CGFloat = 60
        
        let partialEdgeRight = [CGPoint(x: startRight.x+d, y: startRight.y), CGPoint(x:turnRight.x-d, y: turnRight.y)]//[startRight, turnRight]
        let partialEdgeLeft = [CGPoint(x: startLeft.x+d, y: startLeft.y), CGPoint(x:turnLeft.x-d, y: turnLeft.y)]//[startLeft, turnLeft]
        let partialEdgeStart = [CGPoint(x:startLeft.x, y:startLeft.y-d), CGPoint(x:startRight.x, y:startRight.y+d)]
        let partialEdgeTurn = [CGPoint(x:turnLeft.x, y:turnLeft.y-d), CGPoint(x:turnRight.x, y:turnRight.y+d)]
        
        edges = PartialLines(start:partialEdgeStart, right:partialEdgeRight, turn:partialEdgeTurn, left:partialEdgeLeft)
    }
    
    func trackingAreas(owner:PoolViewController) -> [NSTrackingArea] {
        
        var trackingAreas = [NSTrackingArea]()
        
        DragPadIndex.allCases.forEach {
            let point = pointFor(dragPad: $0 )
            let rect = CGRect(x: point.x-dragPadRadius, y:point.y-dragPadRadius, width:2*dragPadRadius, height:2*dragPadRadius)
            let trackingArea = NSTrackingArea(rect: rect,
                                              options: [.mouseEnteredAndExited, .activeAlways],
                                              owner: owner,
                                              userInfo: [TrackingAreaDictionaryKeys.dragPadIndex.rawValue: $0 ] )
            
            trackingAreas.append(trackingArea)
        }
        return trackingAreas
    }
    
    
    func pointFor(poolCorner:PoolCorner) -> CGPoint {
        switch poolCorner {
        case .startLeft:
            return startLeft
        case .startRight:
            return startRight
        case .turnLeft:
            return turnLeft
        case .turnRight:
            return turnRight
        }
    }
    
    // Return the point for the drag pad
    func pointFor(dragPad: DragPadIndex) -> CGPoint {
        let (edgeIndex, end) = edgeIndexAndEndFor(dragPad)
        let line = edges.edgeFor(index: edgeIndex)
        return  line[end]
    }
    
    func shapeLayerForCorner(corner:PoolCorner, in frame:CGRect, name:LayerName) -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.frame = frame
        let path = CGMutablePath()
        let point = pointFor(poolCorner: corner)
        path.addArc(center: point, radius: 5, startAngle: 0, endAngle: CGFloat.pi * 2.0, clockwise: true)
        layer.path = path
        layer.strokeColor = NSColor.yellow.cgColor
        layer.fillColor = NSColor.yellow.cgColor
        layer.lineWidth = 1.0
        layer.name =  name.rawValue
        return layer
    }
    
    func shapeLayerPoolEdges(in frame:CGRect, name:LayerName) -> CAShapeLayer {
        
        let layer = CAShapeLayer()
        layer.frame = frame
        let path = CGMutablePath()

        PartialLines.EdgeIndex.allCases.forEach {
            let line = edges.edgeFor(index: $0 )
            path.move(to: line[0])
            path.addLine(to: line[1])
        }
        
        layer.path = path
        layer.strokeColor = NSColor.yellow.cgColor
        layer.lineWidth = 2
        layer.name = name.rawValue
        
        return layer
    }
    
    // Return layer with sublayers containing the edge text as CATextLayers
    func textLayerForPoolEdges(in frame: CGRect, name: LayerName) -> CALayer {
        let layer = CALayer()
        layer.name = name.rawValue
        PartialLines.EdgeIndex.allCases.forEach {
            let tShape = textLayerForPoolEdge(edgeIndex: $0, in: frame, name: name)
            layer.addSublayer(tShape)
        }
        return layer
    }
    
    // return a text layer with the text for the given edge index
    func textLayerForPoolEdge(edgeIndex:PartialLines.EdgeIndex, in frame:CGRect, name:LayerName) -> CATextLayer {
        
        let layer = CATextLayer()
        layer.name = name.rawValue
        layer.fontSize = 18
        layer.foregroundColor = NSColor.red.cgColor
        layer.string = edges.stringFor(edgeIndex)
        
        let edge = edges.edgeFor(index: edgeIndex)
        let left = edge[0]
        let right = edge[1]

        let width = left.distanceToPoint(right)
        
        layer.frame = CGRect(x:0, y:0, width: width, height:layer.fontSize * 1.25)
        layer.position = left
        layer.alignmentMode = .center

        layer.anchorPoint = CGPoint(x: 0, y: 1)
        
        let angle = left.angleBetweenPoints(firstPoint: right, secondPoint: CGPoint(x:100000, y:left.y))
        let rotate = CGAffineTransform(rotationAngle: angle)
        layer.transform = CATransform3DMakeAffineTransform(rotate)

        return layer
    }
    
    // Return the layer for the magnifying drag pad with the magnified image in it
    func layerForMagnifingDragPad(padIndex:DragPadIndex, in frame:CGRect, name:LayerName, image:CGImage) -> CALayer {

        let point = pointFor(dragPad: padIndex)
        let nsImage = NSImage(cgImage: image, size: frame.size)
        let resizedImage = nsImage.resized(to: NSSize(width: padMagnify * frame.size.width, height: padMagnify * frame.size.height))
        
        // Create a new layer and put the resized image into it
        let imageLayer = CALayer()
        imageLayer.contents = resizedImage
        imageLayer.frame = CGRect(x: 0, y: 0, width: resizedImage!.size.width, height: resizedImage!.size.height)
        
        // Create the mask that will be applied to the layer
        let radius = padScaling * dragPadRadius
        let center = CGPoint(x:padMagnify * point.x, y: padMagnify * point.y)
        let maskPath = CGMutablePath()
        maskPath.addArc(center: center, radius: radius, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: true)
        
        let maskLayer = CAShapeLayer()
        maskLayer.path = maskPath
        maskLayer.name = name.rawValue
        
        // apply the mask to the image layer
        imageLayer.mask = maskLayer
        imageLayer.name = name.rawValue
        
        // Translate the image layer back to the desired location -- the scaling moved it away
        let tx:CGFloat = point.x - center.x
        let ty:CGFloat = point.y - center.y
        let move = CGAffineTransform(translationX: tx, y: ty)
        imageLayer.transform = CATransform3DMakeAffineTransform(move)
        
        return imageLayer
    }
    
    // return the drag pad layer for the given pad index
    func shapeLayerForDragPad(padIndex:DragPadIndex, frame:CGRect, name:LayerName) -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.frame = frame
        let path = CGMutablePath()
        
        let point = pointFor(dragPad: padIndex)
                   
        path.addArc(center: point, radius:dragPadRadius, startAngle: 0.0, endAngle: CGFloat.pi * 2.0, clockwise: false)
        
        layer.fillColor = CGColor(gray: 1, alpha: 0.5)

        layer.path = path
        layer.strokeColor = NSColor.black.cgColor
        layer.lineWidth = 1.0
        layer.name = name.rawValue
        
        return layer
    }
    
    // return all of the drag pads in a single layer
    func shapeLayerForDragPads(in frame: CGRect, name:LayerName) -> CAShapeLayer {
        
        let layer = CAShapeLayer()
        layer.frame = frame
        let path = CGMutablePath()
        
        DragPadIndex.allCases.forEach {
            let point = pointFor(dragPad: $0 )
            path.move(to: point)
            path.addArc(center: point, radius:dragPadRadius, startAngle: 0.0, endAngle: CGFloat.pi * 2.0, clockwise: false)
        }
        
        layer.fillColor = CGColor(gray: 1, alpha: 0.5)
        layer.path = path
        layer.strokeColor = NSColor.black.cgColor
        layer.lineWidth = 1.0
        layer.name = name.rawValue
        
        return layer
    }
    
    // return true and padIndex if point contained in a dragPad, false otherwise
    func isPointContainedByAnyDragPad(_ point:CGPoint) -> (Bool, DragPadIndex) {
        
        for padIndex in DragPadIndex.allCases {
            
            let p = pointFor(dragPad: padIndex )
            if point.distanceToPoint(p) < dragPadRadius {
                return (true, padIndex)
            }
        }
        return (false, .leftBegin)
    }
    
    // return the edge index and which end of the edge this dragpad will affect
    private func edgeIndexAndEndFor(_ dragPadIndex:DragPadIndex) -> (PartialLines.EdgeIndex, Int) {
        
        switch dragPadIndex {
        case .leftBegin:
            return ( .left, 0)
        case .leftEnd:
            return ( .left, 1)
        case .rightBegin:
            return ( .right, 0)
        case .rightEnd:
            return ( .right, 1 )
        case .startBegin:
            return (.start, 0)
        case .startEnd:
            return ( .start, 1)
        case .turnBegin:
            return ( .turn, 0)
        case .turnEnd:
            return ( .turn, 1)
        }
    }
    
    // return true if point + offset inside frame, false with needed changes to offset to keep inside frame
    func updatedEdgeInView(dragPadIndex:DragPadIndex, offset:CGSize, frame:CGRect) -> (Bool, CGSize) {
        
        let point = pointFor(dragPad: dragPadIndex)
        let newPoint = CGPoint(x:point.x - offset.width, y:point.y - offset.height)
        let f = CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height)
        
        var adjX:CGFloat = 0
        var adjY:CGFloat = 0
        if f.contains(newPoint) {
            return (true, CGSize.zero)
        } else {
            if newPoint.x < 0 {
                adjX =   -newPoint.x
            }
            if newPoint.x > f.size.width {
                adjX = f.size.width - newPoint.x
            }
            if newPoint.y < 0 {
                adjY =  -newPoint.y
            }
            if newPoint.y > f.size.height {
                adjY = f.size.height - newPoint.y
            }
            return(false, CGSize(width: adjX, height: adjY))
        }
        
    }
    
    // update the line, but keep the line point on screen by adjusting the offset as necessary
    func updateEdge(dragPadIndex:DragPadIndex, offset:CGSize) {
        
        let (lineIndex, end) = edgeIndexAndEndFor(dragPadIndex)
        let line = edges.edgeFor(index: lineIndex)
        let point = line[end]
        
        let newPoint = CGPoint(x:point.x - offset.width, y:point.y - offset.height)
        var newLine:Line
        if end == 0 {
            newLine = [newPoint, line[1]]
        } else {
            newLine = [line[0], newPoint]
        }
        edges.updateEdge(lineIndex, newLine)
        
        updatePoolCorners()
    }
    
    func updatePoolCorners() {
        // using the pool edges, update the pool corners as the intersections of those edges
                
        if let point = linesCross(line1: edges.start, line2: edges.left) {
            startLeft = point
        }
        
        if let point = linesCross(line1: edges.start, line2: edges.right) {
            startRight = point
        }
        
        if let point = linesCross(line1: edges.turn, line2: edges.left) {
            turnLeft = point
        }
        
        if let point = linesCross(line1: edges.turn, line2: edges.right) {
            turnRight = point
        }
    }
    
    private func linesCross(line1:Line, line2:Line) -> CGPoint? {
        
        var intersectionPoint = CGPoint.zero
                
        let x1 = line1[0].x
        let x2 = line1[1].x
        let x3 = line2[0].x
        let x4 = line2[1].x
        
        let y1 = line1[0].y
        let y2 = line1[1].y
        let y3 = line2[0].y
        let y4 = line2[1].y
        
        let x1Minusx2 = x1 - x2
        let x3Minusx4 = x3 - x4
        let y1Minusy2 = y1 - y2
        let y3Minusy4 = y3 - y4
        
        let denominator = x1Minusx2 * y3Minusy4 - y1Minusy2 * x3Minusx4;
        
        //TODO: check denominator sufficiently close to zero
        // if (Mathf.Approximately(denominator, 0))
        // return nil
        
        let a = (x1 * y2 - y1 * x2)
        let b = (x3 * y4 - y3 * x4)
        let ax3MinusX4 = a * x3Minusx4
        let ay3Minusy4 = a * y3Minusy4
        
        
        //x
        var numerator = ax3MinusX4 - x1Minusx2 * b
        let x = numerator / denominator
        
        //y
        //numerator = ax3MinusX4 - y1Minusy2 * b
        numerator = ay3Minusy4 - y1Minusy2 * b;

        let y = numerator / denominator
        
        intersectionPoint = CGPoint(x: x, y:y)
        
        return intersectionPoint
        
    }
}

extension NSImage {
    func resized(to newSize: NSSize) -> NSImage? {
        if let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(newSize.width), pixelsHigh: Int(newSize.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) {
            bitmapRep.size = newSize
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
            draw(in: NSRect(x: 0, y: 0, width: newSize.width, height: newSize.height), from: .zero, operation: .copy, fraction: 1.0)
            NSGraphicsContext.restoreGraphicsState()

            let resizedImage = NSImage(size: newSize)
            resizedImage.addRepresentation(bitmapRep)
            return resizedImage
        }
        return nil
    }
}
