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
		var padTop = 2;
		var padBottom = 2;
		var usableH = h - padTop - padBottom;

		var pts = [];
		var maxV = 0;

		for(var i = 0; i < samples.length; i++) {
			var s = samples[i];

			if(!s || s.t < cutoff) {
				continue;
			}

			if(s.ok && s.v >= 0) {
				pts.push(s);

				if(s.v > maxV) {
					maxV = s.v;
				}
			}
		}

		if(pts.length < 2 || maxV <= 0) {
			return;
		}

		var tMin = pts[0].t;
		var tMax = pts[pts.length - 1].t;

		if(tMax <= tMin) {
			tMax = tMin + 1;
		}

		var step = Math.max(1, Math.ceil(pts.length / 240));
		var firstX = 0;
		var lastX = 0;
		var first = true;

		ctx.beginPath();

		for(var j = 0; j < pts.length; j += step) {
			var p = pts[j];
			var x = ((p.t - tMin) / (tMax - tMin)) * w;
			var y = padTop + usableH - ((p.v / maxV) * usableH);

			if(first) {
				ctx.moveTo(x, y);
				firstX = x;
				first = false;
			} else {
				ctx.lineTo(x, y);
			}

			lastX = x;
		}

		var c = lineColor;
		ctx.strokeStyle = c;
		ctx.lineWidth = 1.2;
		ctx.stroke();

		ctx.lineTo(lastX, padTop + usableH);
		ctx.lineTo(firstX, padTop + usableH);
		ctx.closePath();
		ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, 0.12);
		ctx.fill();

		ctx.fillStyle = offlineColor;

		for(var k = 0; k < samples.length; k++) {
			var o = samples[k];

			if(!o || o.ok || o.t < cutoff) {
				continue;
			}

			var mx = ((o.t - tMin) / (tMax - tMin)) * w;

			if(mx < 0 || mx > w) {
				continue;
			}

			ctx.fillRect(mx - 1.5, h - padBottom - 3, 3, 3);
		}
	}
}
