# Report of Scalar-on-Network Regression

**Abstract** There is a growing trend in learning the association between individuals’ brain connectivity networks and their clinical characteristics as well as symptoms. It requires a kind of model whose response variable is scalar, and the predictors are networks or adjacent matrices. Therefore, in this research, we developed a new boosting method for variable screening. The performance of our method was demonstrated through analysis of the rs-fMRI data.

## Introduction

Functional connectome fingerprinting (Finn et al., 2015) has aroused heated discussion over recent years since it implies some clinical symptoms or demographic characteristics. Previous research used various regression methods (Dubois, Galdi, Han, et al., 2018; Dubois, Galdi, Paul, et al., 2018; Tozzi et al., 2021) or dimension reduction approaches (Sripada, Angstadt, et al., 2020; Sripada, Rutherford, et al., 2020) to extract relevant information from functional connectivity. However, they either failed to perform variable screening or omitted the brain structure information, which is deficient for the identification of sub-networks or edges that contribute to certain diseases. Thus, our research goal is to find biomarkers of certain diseases or brain functions, while extracting their information as much as possible.

## Methods

### Algorithm Development

Boosting algorithm was developed to improve prediction by combining weak learners, and it has evolved into various adaptations. Among them, $L_2$ boosting has shown excellent performance in high-dimensional settings (Bühlmann, 2006), with a wide range of applications in brain imaging and genomics. Here we developed a two-stage $L_2$ boosting algorithm to perform variable selection in a group structure. The first stage is for group (brain network pairs) selection. Assume that edges (brain region pairs) that distribute in the same group have similar effects on cognition or other features. Hence, the predictors were acquired by averaging the functional connectivity within each group, and the response variables are individuals' characteristics. Then we utilize $L_2$ boosting to select informative groups. The second stage is for edge selection, we first choose edges belonging to selected groups as predictors, and still treat individuals’ characteristics as response variables, then we perform $L_2$ boosting to further select informative edges. Unlike previous algorithms which run multiple times in a cross-validation set-up, to make our method computationally attractive, we used corrected AIC/BIC criteria (Bühlmann, 2006; Chen & Chen, 2008) to stop the iteration. We prefer the AIC criterion in the first stage for small errors and the BIC criterion in the second stage to avoid overfitting.

### rs-fMRI analysis

We applied our method to reveal neural substrates of general cognitive ability.

##### Functional Connectivity generation

To generate functional connectivity matrices, we first parcellated the brain with Kong’s parcellation (Kong et al., 2021), which exhibited the best homogeneity within each network. Then we calculate ROI-wise functional connectivity with Pearson correlation and transformed it to Fisher-Z. 

**Extraction of general cognitive ability**

To acquire general cognitive ability as the response variable, we conducted an explanatory factor analysis on 10 cognitive batteries from the HCP. 

**K-fold cross-validation**

Finally, we evaluated our method by repeating 10-fold cross-validation 50 times. 

**Permutation test**

To further assess the performance of our method and identify the sub-network of intelligence, we developed a nonparametric permutation test. Topological null models (Váša & Mišić, 2022) were constructed by randomizing the connection points of each edge in functional connectivity matrices, while still preserving their connection strength. Then we treat them as predictors in cross-validation, regarding the output statistics on null models as baselines. After that, we permutated the data both from null models and empirical models (real functional connectivity matrix) 1000 times, calculating the average distance and the significance. We used the coefficient of determination as an assessment of performance, and selected times (non-zero times of $\pmb{\omega}$) as the selection robustness.

## Results

**Summary of Performance**

|  Method  |      MSE      |    ${R}^2$    |    elapsed    |     edges     |
| :------: | :-----------: | :-----------: | :-----------: | :-----------: |
| `GBoost` | 0.889 (0.051) | 0.153 (0.058) | 825.1 (32.76) | 107.9 (1.825) |
| `Lasso`  | 1.050 (0.045) | 0.008 (0.046) | 11.36 (2.399) | 60.18 (32.74) |
| `Ridge`  | 0.928 (0.030) | 0.124 (0.047) | 36.59 (4.477) |       -       |

Here, $\pmb{\mathsf{MSE}}$ is mean squared error, $R^2$ is coefficient of determination, $\pmb{\mathsf{elapsed}}$ is the running time and $\pmb{\mathsf{edges}}$ is the average number of selected edges across folds.

As we can see, our method is outperformed other regression approaches with larger explained variance. Moreover, it can robustly select informative edges across folds, while preserving information as much as possible.

**Permutation Test**

<img src="fig/perm/coeffD_SNreg.svg" width="200px" title="SNreg" /><img src="fig/perm/coeffD_lasso.svg" width="200px" title="lasso" /><img src="fig/perm/coeffD_ridge.svg" width="200px" title="ridge" />

We exclusively compared our method with Lasso. As it indicated, our method can explain larger variance of the data, while Lasso failed to interpret information from individual's functional connectivity.

**Edge Selection**

To further demonstrate the neural substrates of intelligence, we visualize the selection times of each informative edge. I checked the $\pmb{\omega}$ value and accordingly relabeled the selected times, in order to indicate signs of their signals. Specifically, for a certain edge, speculate whether its $\omega_{i,j}$ was all negative or positive across folds where it was selected, then relabeled negative edges with negative selected times, while kept positive ones the same. Fortunately, selected edges all have consistent signs across different folds. Thus there is no controversy in relabeling their selected times.

It is suggested that, most of the edges concentrated in the default mode network and the control network. Furthermore, the selected edges spread across all eight work, which indicates that the general cognitive ability might be the function of the whole brain. We can also observe some lateralization in edges related to the visual network and the language network, which may provide some insights into the organization of our brain.

To save loading memory on `github`, I only post the connectome of the control network. Please check `fig >> 3D` for further detailed speculation in 3D view, or check `fig >> 2D` for 2D view.

![conn_DorsAttn](https://user-images.githubusercontent.com/115483486/205982822-8382e33d-cec7-40d8-985f-cd1f7e9eda08.gif)



**Reference**  
Bühlmann, P. (2006). Boosting for high-dimensional linear models. *The Annals of Statistics*, *34*(2). https://doi.org/10.1214/009053606000000092  
Dubois, J., Galdi, P., Han, Y., Paul, L. K., & Adolphs, R. (2018). Resting-State Functional Brain Connectivity Best Predicts the Personality Dimension of Openness to Experience. *Personality Neuroscience*, *1*, e6. https://doi.org/10.1017/pen.2018.8  
Dubois, J., Galdi, P., Paul, L. K., & Adolphs, R. (2018). A distributed brain network predicts general intelligence from resting-state human neuroimaging data. *Philosophical Transactions of the Royal Society B: Biological Sciences*, *373*(1756), 20170284. https://doi.org/10.1098/rstb.2017.0284  
Finn, E. S., Shen, X., Scheinost, D., Rosenberg, M. D., Huang, J., Chun, M. M., Papademetris, X., & Constable, R. T. (2015). Functional connectome fingerprinting: Identifying individuals using patterns of brain connectivity. *Nature Neuroscience*, *18*(11), 1664–1671. https://doi.org/10.1038/nn.4135  
Glasser, M. F., Smith, S. M., Marcus, D. S., Andersson, J. L. R., Auerbach, E. J., Behrens, T. E. J., Coalson, T. S., Harms, M. P., Jenkinson, M., Moeller, S., Robinson, E. C., Sotiropoulos, S. N., Xu, J., Yacoub, E., Ugurbil, K., & Van Essen, D. C. (2016). The Human Connectome Project’s neuroimaging approach. *Nature Neuroscience*, *19*(9), 1175–1187. https://doi.org/10.1038/nn.4361  
Kong, R., Yang, Q., Gordon, E., Xue, A., Yan, X., Orban, C., Zuo, X.-N., Spreng, N., Ge, T., Holmes, A., Eickhoff, S., & Yeo, B. T. T. (2021). Individual-Specific Areal-Level Parcellations Improve Functional Connectivity Prediction of Behavior. *Cerebral Cortex*, *31*(10), 4477–4500. https://doi.org/10.1093/cercor/bhab101  
Sripada, C., Angstadt, M., Rutherford, S., Taxali, A., & Shedden, K. (2020). Toward a “treadmill test” for cognition: Improved prediction of general cognitive ability from the task activated brain. *Human Brain Mapping*, *41*(12), 3186–3197. https://doi.org/10.1002/hbm.25007  
Sripada, C., Rutherford, S., Angstadt, M., Thompson, W. K., Luciana, M., Weigard, A., Hyde, L. H., & Heitzeg, M. (2020). Prediction of neurocognition in youth from resting state fMRI. *Molecular Psychiatry*, *25*(12), 3413–3421. https://doi.org/10.1038/s41380-019-0481-6  
Tozzi, L., Tuzhilina, E., Glasser, M. F., Hastie, T. J., & Williams, L. M. (2021). Relating whole-brain functional connectivity to self-reported negative emotion in a large sample of young adults using group regularized canonical correlation analysis. *NeuroImage*, *237*, 118137. https://doi.org/10.1016/j.neuroimage.2021.118137  
Váša, F., & Mišić, B. (2022). Null models in network neuroscience. *Nature Reviews Neuroscience*, *23*(8), 493–504. https://doi.org/10.1038/s41583-022-00601-9
