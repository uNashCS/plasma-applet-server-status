import QtQuick
import org.kde.kirigami as Kirigami

Canvas {
	id: sparkline

	property var samples: []
	property int windowSeconds: 3600
	property color lineColor: Kirigami.Theme.highlightColor
	property color offlineColor: Kirigami.Theme.negativeTextColor

	antialiasing: true

	onSamplesChanged: requestPaint()
	onWindowSecondsChanged: requestPaint()
	onWidthChanged: requestPaint()
	onHeightChanged: requestPaint()
	onLineColorChanged: requestPaint()
	onOfflineColorChanged: requestPaint()

	function drawDashedLine(ctx, y, w, color) {
		var dash = 4;
		var gap = 4;

		ctx.strokeStyle = color;
		ctx.lineWidth = 1;

		for(var x = 0; x < w; x += dash + gap) {
			ctx.beginPath();
			ctx.moveTo(x, y);
			ctx.lineTo(Math.min(x + dash, w), y);
			ctx.stroke();
		}
	}

	onPaint: {
		var ctx = getContext("2d");
		var w = width;
		var h = height;

		ctx.reset();
		ctx.clearRect(0, 0, w, h);

		if(!samples || samples.length === 0) {
			return;
		}

		var now = Date.now() / 1000;
		var cutoff = now - windowSeconds;
		var padTop = 3;
		var padBottom = 3;
		var usableH = h - padTop - padBottom;

		var visible = [];
		var pts = [];
		var maxV = 0;
		var sum = 0;

		for(var i = 0; i < samples.length; i++) {
			var s = samples[i];

			if(!s || s.t < cutoff) {
				continue;
			}

			visible.push(s);

			if(s.ok && s.v >= 0) {
				pts.push(s);
				sum += s.v;

				if(s.v > maxV) {
					maxV = s.v;
				}
			}
		}

		if(pts.length < 2 || maxV <= 0) {
			return;
		}

		var tMin = visible[0].t;
		var tMax = visible[visible.length - 1].t;

		if(tMax <= tMin) {
			tMax = tMin + 1;
		}

		maxV *= 1.15;

		var timeToX = function(t) {
			return ((t - tMin) / (tMax - tMin)) * w;
		};

		var valueToY = function(v) {
			return padTop + usableH - ((v / maxV) * usableH);
		};

		ctx.fillStyle = Qt.rgba(offlineColor.r, offlineColor.g, offlineColor.b, 0.16);

		for(var o = 0; o < visible.length; o++) {
			var os = visible[o];

			if(os.ok) {
				continue;
			}

			var ox = timeToX(os.t);
			ctx.fillRect(ox - 1, padTop, 2, usableH);
		}

		var avgInterval = (tMax - tMin) / Math.max(1, pts.length - 1);
		var gapLimit = Math.max(3, avgInterval * 3);

		var segments = [];
		var current = [];

		for(var p = 0; p < pts.length; p++) {
			if(current.length > 0 && (pts[p].t - current[current.length - 1].t) > gapLimit) {
				segments.push(current);
				current = [];
			}

			current.push(pts[p]);
		}

		if(current.length > 0) {
			segments.push(current);
		}

		var c = lineColor;

		for(var g = 0; g < segments.length; g++) {
			var seg = segments[g];

			if(seg.length === 1) {
				ctx.beginPath();
				ctx.fillStyle = c;
				ctx.arc(timeToX(seg[0].t), valueToY(seg[0].v), 2, 0, Math.PI * 2);
				ctx.fill();
				continue;
			}

			var step = Math.max(1, Math.ceil(seg.length / 240));

			ctx.beginPath();
			ctx.moveTo(timeToX(seg[0].t), valueToY(seg[0].v));

			for(var j = step; j < seg.length; j += step) {
				ctx.lineTo(timeToX(seg[j].t), valueToY(seg[j].v));
			}

			var last = seg[seg.length - 1];

			if((seg.length - 1) % step !== 0) {
				ctx.lineTo(timeToX(last.t), valueToY(last.v));
			}

			ctx.strokeStyle = c;
			ctx.lineWidth = 1.4;
			ctx.stroke();

			var lastX = timeToX(last.t);
			var firstX = timeToX(seg[0].t);
			ctx.lineTo(lastX, padTop + usableH);
			ctx.lineTo(firstX, padTop + usableH);
			ctx.closePath();
			ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, 0.12);
			ctx.fill();
		}

		var avg = sum / pts.length;
		drawDashedLine(ctx, valueToY(avg), w, Qt.rgba(c.r, c.g, c.b, 0.45));

		var lastPoint = pts[pts.length - 1];

		ctx.beginPath();
		ctx.fillStyle = c;
		ctx.arc(timeToX(lastPoint.t), valueToY(lastPoint.v), 2.6, 0, Math.PI * 2);
		ctx.fill();
	}
}
