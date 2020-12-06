perl build_graph.pl ../database > ../database/GameAncestory.dot;

dot -Tsvg ../database/GameAncestory.dot > ../database/GameAncestory.svg;
dot -Tpng ../database/GameAncestory.dot > ../database/GameAncestory.png;
#dot -Tpng:cairo ../database/GameAncestory.dot > ../database/GameAncestory.png;
#dot -Tbmp ../database/GameAncestory.dot > ../database/GameAncestory.bmp;
