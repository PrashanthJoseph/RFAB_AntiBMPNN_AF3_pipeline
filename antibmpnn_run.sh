#!/bin/bash
set -euo pipefail

########################################
# Required inputs (no defaults)
########################################
PDB_DIR=""

########################################
# Optional inputs
########################################
ANTI_BMPNN_ROOT="/mnt/c/Users/Inito/INITO_PROJECT/Protein-Protein/AntiBMPNN/AntiBMPNN"
CHAINS_TO_DESIGN="H L"

# AntiBMPNN params
NUM_SEQ_PER_TARGET=1000
SAMPLING_TEMP="0.1"
BATCH_SIZE=10
BACKBONE_NOISE=0.5
OMIT_AAS='C'

# Optional overrides
RUN_ID=""
THEME=""
OUTPUT_DIR=""

########################################
# Usage
########################################
usage() {
  cat <<EOF
Usage:
  $0 --pdb_dir PATH [options]

Required:
  --pdb_dir PATH

Optional:
  --anti_bmpnn_root PATH
  --chains "H L"
  --run_id ID
  --theme NAME
  --output_dir PATH

AntiBMPNN:
  --num_seq_per_target N
  --sampling_temp T
  --batch_size N
  --backbone_noise N
  --omit_AAs STR

Defaults:
  run_id     = YYYYMMDD_HHMMSS_<hash>
  theme      = <run_id>_design_fixed_positions
  output_dir = <pdb_dir>/<run_id>_output
EOF
}

########################################
# Arg parsing
########################################
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pdb_dir) PDB_DIR="$2"; shift 2;;

    --anti_bmpnn_root) ANTI_BMPNN_ROOT="$2"; shift 2;;
    --chains|--chains_to_design) CHAINS_TO_DESIGN="$2"; shift 2;;

    --run_id) RUN_ID="$2"; shift 2;;
    --theme) THEME="$2"; shift 2;;
    --output_dir) OUTPUT_DIR="$2"; shift 2;;

    --num_seq_per_target) NUM_SEQ_PER_TARGET="$2"; shift 2;;
    --sampling_temp) SAMPLING_TEMP="$2"; shift 2;;
    --batch_size) BATCH_SIZE="$2"; shift 2;;
    --backbone_noise) BACKBONE_NOISE="$2"; shift 2;;
    --omit_AAs) OMIT_AAS="$2"; shift 2;;

    -h|--help) usage; exit 0;;
    *) echo "Unknown argument: $1"; usage; exit 1;;
  esac
done

########################################
# Validation
########################################
if [[ -z "$PDB_DIR" ]]; then
  echo "ERROR: --pdb_dir is required"
  usage
  exit 1
fi

########################################
# Strong run ID
########################################
if [[ -z "$RUN_ID" ]]; then
  RUN_ID="$(openssl rand -hex 3)"
fi

########################################
# Derived defaults
########################################
if [[ -z "$THEME" ]]; then
  THEME="${RUN_ID}_design_fixed_positions"
fi

if [[ -z "$OUTPUT_DIR" ]]; then
  OUTPUT_DIR="${PDB_DIR}/${RUN_ID}_output"
fi

mkdir -p "$OUTPUT_DIR"

########################################
# Paths
########################################
PATH_PARSED_CHAINS="$OUTPUT_DIR/parsed_pdbs.jsonl"
PATH_ASSIGNED_CHAINS="$OUTPUT_DIR/assigned_pdbs.jsonl"
PATH_FIXED_POSITIONS="$OUTPUT_DIR/fixed_pdbs.jsonl"

########################################
# Echo config (for reproducibility)
########################################
echo "============================================"
echo "RUN_ID:              $RUN_ID"
echo "PDB_DIR:             $PDB_DIR"
echo "OUTPUT_DIR:          $OUTPUT_DIR"
echo "THEME:               $THEME"
echo "CHAINS_TO_DESIGN:    $CHAINS_TO_DESIGN"
echo "NUM_SEQ_PER_TARGET:  $NUM_SEQ_PER_TARGET"
echo "SAMPLING_TEMP:       $SAMPLING_TEMP"
echo "BATCH_SIZE:          $BATCH_SIZE"
echo "BACKBONE_NOISE:      $BACKBONE_NOISE"
echo "OMIT_AAS:            $OMIT_AAS"
echo "============================================"

########################################
# Preprocessing
########################################
python "${ANTI_BMPNN_ROOT}/helper_scripts/parse_multiple_chains.py" \
  --input_path="$PDB_DIR" \
  --output_path="$PATH_PARSED_CHAINS"

python "${ANTI_BMPNN_ROOT}/helper_scripts/assign_fixed_chains.py" \
  --input_path="$PATH_PARSED_CHAINS" \
  --output_path="$PATH_ASSIGNED_CHAINS" \
  --chain_list "$CHAINS_TO_DESIGN"

python "${ANTI_BMPNN_ROOT}/helper_scripts/make_fixed_positions_from_motifs.py" \
  --input_path="$PATH_PARSED_CHAINS" \
  --output_path="$PATH_FIXED_POSITIONS" \
  --chains "$CHAINS_TO_DESIGN"

########################################
# Run AntiBMPNN
########################################
python "${ANTI_BMPNN_ROOT}/Running_AntiBMPNN_run.py" \
  --jsonl_path "$PATH_PARSED_CHAINS" \
  --chain_id_jsonl "$PATH_ASSIGNED_CHAINS" \
  --fixed_positions_jsonl "$PATH_FIXED_POSITIONS" \
  --out_folder "$OUTPUT_DIR" \
  --model_name "antibmpnn_000" \
  --num_seq_per_target "$NUM_SEQ_PER_TARGET" \
  --sampling_temp "$SAMPLING_TEMP" \
  --batch_size "$BATCH_SIZE" \
  --backbone_noise "$BACKBONE_NOISE" \
  --omit_AAs "$OMIT_AAS"

echo "============================================"
echo "All PDBs processed!"
echo "Sequences: ${OUTPUT_DIR}/seqs/"
echo "============================================"
