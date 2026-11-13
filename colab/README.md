# Temporary RestoreAI Colab server — Arabic quick start

1. Open [RestoreAI_Temporary_GPU_Server.ipynb](RestoreAI_Temporary_GPU_Server.ipynb) in Google Colab (use the **feature/bilingual-ui** branch).
2. Choose **Runtime → Change runtime type → T4 GPU**. Free GPU availability is not guaranteed.
3. Run notebook cells from top to bottom. Do not skip the **real inference test** cell.
4. The tunnel cell prints a temporary **SERVER URL** and a private **ACCESS TOKEN**. Do not share the token or screenshots showing it.
5. Install the latest RestoreAI Android APK from GitHub Actions. Inside the app, tap **ربط خادم Colab المؤقت**, paste URL and token, select the photo, draw the mask and tap **ترميم الصورة**.
6. Keep Colab running until restoration finishes. Tunnel URL changes when restarting. End the Colab runtime afterward.

**Important:** The notebook has been committed but has not been executed on a Colab GPU by the assistant. If a cell fails, copy its **error text only** (redact token and any private photos) for debugging. The image is uploaded to your temporary server over HTTPS; use only photos you have permission to process. The backend limits uploads to 8 MB and 2 megapixels. The model's output is an estimate, not an exact recovery of lost pixels.
