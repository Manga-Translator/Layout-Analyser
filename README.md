# Layout-Analyser
Analyses the layout of a page and locates text which can be extracted for translation.

This is the current progress on the portion of the translator that performs document layout analysis and extracts the text regions in the page along with metadata describing their location (and perhaps type, ie whether they are from a speech bubble, or free-form text) so that they can be OCR'd.

Since the OCR required is to be performed by Tesseract, and translation is to be performed by an external service, like google translate, this forms the meat of the translator's functionality. It's possible that I may (at least temporarily) release a version where this job can bypassed and performed by a human, if real-world tests prove it to be unreliable.

Current implementation is in Turing 4.1.1, but will be translated into C when more feature-complete. The choice of Turing is currently for the purposes of having a safer language to prototype in which is easier to debug. An added side benefit is the poor performance of the language, especially when drawing all operations done by the program graphically to the screen, which has proven to be a major aid to optimization. Turing's data structure inflexibility may prove problematic however, as more complex operations are to be carried out.

The last period of development was in January and was interrupted by academic responsibilities. Hopefully enough progress can be made in the next couple of months to have a beta release of the translator done by the end of April, though this may be optimistic.
