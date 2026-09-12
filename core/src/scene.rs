//! Serializable, non-destructive annotation scene model.

use serde::{Deserialize, Serialize};

pub const DOCUMENT_VERSION: u32 = 1;

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct Point {
    pub x: f64,
    pub y: f64,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct Rect {
    pub left: f64,
    pub top: f64,
    pub width: f64,
    pub height: f64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct RgbaColor {
    pub red: u8,
    pub green: u8,
    pub blue: u8,
    pub alpha: u8,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct StrokeStyle {
    pub color: RgbaColor,
    pub width: f64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum Annotation {
    Rectangle {
        bounds: Rect,
        style: StrokeStyle,
        filled: bool,
    },
    Ellipse {
        bounds: Rect,
        style: StrokeStyle,
    },
    Arrow {
        start: Point,
        end: Point,
        style: StrokeStyle,
    },
    Pen {
        points: Vec<Point>,
        style: StrokeStyle,
    },
    Text {
        origin: Point,
        value: String,
        font_size: f64,
        color: RgbaColor,
    },
    Sticker {
        center: Point,
        value: String,
        size: f64,
    },
    Mosaic {
        bounds: Rect,
        block_size: u32,
        ai_mask: bool,
    },
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SceneDocument {
    pub version: u32,
    pub canvas_width: u32,
    pub canvas_height: u32,
    pub annotations: Vec<Annotation>,
    /// Visible region of the base image in physical pixels. `None` shows the
    /// whole image. A crop is part of the document rather than a raster edit,
    /// so annotations keep their base-image coordinates and it can be undone.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub crop: Option<Rect>,
}

impl SceneDocument {
    pub fn new(canvas_width: u32, canvas_height: u32) -> Self {
        Self {
            version: DOCUMENT_VERSION,
            canvas_width,
            canvas_height,
            annotations: Vec::new(),
            crop: None,
        }
    }

    /// Size of the exported raster: the crop when present, else the canvas.
    pub fn export_size(&self) -> (u32, u32) {
        match self.crop {
            Some(crop) => (
                crop.width.round().max(1.0) as u32,
                crop.height.round().max(1.0) as u32,
            ),
            None => (self.canvas_width, self.canvas_height),
        }
    }

    pub fn to_json(&self) -> Result<String, serde_json::Error> {
        serde_json::to_string_pretty(self)
    }

    pub fn from_json(json: &str) -> Result<Self, serde_json::Error> {
        serde_json::from_str(json)
    }
}

#[derive(Debug, Clone)]
pub struct SceneHistory {
    current: SceneDocument,
    undo: Vec<SceneDocument>,
    redo: Vec<SceneDocument>,
}

impl SceneHistory {
    pub fn new(document: SceneDocument) -> Self {
        Self {
            current: document,
            undo: Vec::new(),
            redo: Vec::new(),
        }
    }

    pub fn current(&self) -> &SceneDocument {
        &self.current
    }

    pub fn push_annotation(&mut self, annotation: Annotation) {
        self.undo.push(self.current.clone());
        self.redo.clear();
        self.current.annotations.push(annotation);
    }

    /// Crops (or, with `None`, un-crops) the document as one undoable step.
    pub fn set_crop(&mut self, crop: Option<Rect>) {
        if self.current.crop == crop {
            return;
        }
        self.undo.push(self.current.clone());
        self.redo.clear();
        self.current.crop = crop;
    }

    pub fn undo(&mut self) -> bool {
        let Some(previous) = self.undo.pop() else {
            return false;
        };
        self.redo
            .push(std::mem::replace(&mut self.current, previous));
        true
    }

    pub fn redo(&mut self) -> bool {
        let Some(next) = self.redo.pop() else {
            return false;
        };
        self.undo.push(std::mem::replace(&mut self.current, next));
        true
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn rectangle() -> Annotation {
        Annotation::Rectangle {
            bounds: Rect {
                left: 10.0,
                top: 12.0,
                width: 100.0,
                height: 50.0,
            },
            style: StrokeStyle {
                color: RgbaColor {
                    red: 255,
                    green: 52,
                    blue: 76,
                    alpha: 255,
                },
                width: 3.0,
            },
            filled: true,
        }
    }

    #[test]
    fn scene_round_trips_through_json() {
        let mut document = SceneDocument::new(1920, 1080);
        document.annotations.push(rectangle());
        let json = document.to_json().expect("scene should serialize");
        assert_eq!(SceneDocument::from_json(&json).unwrap(), document);
    }

    #[test]
    fn undo_and_redo_restore_scene_versions() {
        let mut history = SceneHistory::new(SceneDocument::new(800, 600));
        history.push_annotation(rectangle());
        assert_eq!(history.current().annotations.len(), 1);
        assert!(history.undo());
        assert!(history.current().annotations.is_empty());
        assert!(history.redo());
        assert_eq!(history.current().annotations.len(), 1);
    }

    #[test]
    fn new_edit_clears_redo_history() {
        let mut history = SceneHistory::new(SceneDocument::new(800, 600));
        history.push_annotation(rectangle());
        assert!(history.undo());
        history.push_annotation(rectangle());
        assert!(!history.redo());
    }

    #[test]
    fn crop_is_an_undoable_document_step_that_sets_the_export_size() {
        let crop = Rect {
            left: 100.0,
            top: 50.0,
            width: 640.0,
            height: 480.0,
        };
        let mut history = SceneHistory::new(SceneDocument::new(1920, 1080));
        history.push_annotation(rectangle());
        history.set_crop(Some(crop));
        assert_eq!(history.current().export_size(), (640, 480));
        assert_eq!(history.current().annotations.len(), 1);
        // Setting the same crop again is not a history entry.
        history.set_crop(Some(crop));
        assert!(history.undo());
        assert_eq!(history.current().crop, None);
        assert_eq!(history.current().export_size(), (1920, 1080));
        assert!(history.redo());
        assert_eq!(history.current().crop, Some(crop));
    }

    #[test]
    fn documents_without_a_crop_still_load() {
        let json = r#"{"version":1,"canvas_width":10,"canvas_height":5,"annotations":[]}"#;
        let document = SceneDocument::from_json(json).unwrap();
        assert_eq!(document.crop, None);
        assert!(!document.to_json().unwrap().contains("crop"));
        let mut cropped = document.clone();
        cropped.crop = Some(Rect {
            left: 1.0,
            top: 1.0,
            width: 4.0,
            height: 2.0,
        });
        let json = cropped.to_json().unwrap();
        assert_eq!(SceneDocument::from_json(&json).unwrap(), cropped);
    }
}
