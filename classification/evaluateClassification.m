function Results = evaluateClassification(Results, options)
% Evaluate the result of an evaluation
% The input struct is the ouput struct, there are only additional fields 
% added.
% Input:
% - Results: The crossvalidation result struct, as generated by 
%            the crossValidate function. (see crossValidate for a 
%            list of initial members
% - options: Struct with ption fields:
%       * disp: Display the evaluation (binary)
%       * roc: Generate a ROC curve. This works only for SVMs with linear 
%              Kernels, and for 2-class problems (binary)
%       * rocSamples: Samples of the ROC
% Output:
% The Result struct, but with additional entries:
%       * confusionMatrices: The confusion matrix of the single 
%           crossValidation runs
%       * confusionMatrix: The complete confusion matrix of the
%           crossValidation.
%       * confusionMatrixNormed: The confusion matrix of the
%           crossValidation, with lines and columns normed to 1.
%       * classificationRate: The classwise averaged classification rate
%           (average of the diagonal entries of the normed confusion
%           matrix).
%       * roc: The roc curve. It is calculated as follows:
%           The Hyperplane of the linear SVM is is moved along its
%           orthogonal (i.e. the discriminators of the data set entries
%           are thresholded). 
%       * auRoc: Area under the ROC      
% Additionally, the outputs of the cross validation runs are flattened,
% which yields the following entries:
%       * allGoldstandard: The gold standard 
%       * allResult: The result
%       * allDiscriminators: The discriminators (for SVMs)
%       * allCorrect = Binary vector: Was the decision correct?
%       * allValid = The valid data sets for the cross validation runs,
%                    i.e. the data actually used
%       * numSamplesClasses: The number of samples for each class.


% -------------------------------------------------------------------------
% Calculate confusion matrices
Results.confusionMatrices = cell(Results.numFolds, 1);
Results.confusionMatrix = zeros(numel(Results.classes));
for numRun = 1:Results.numFolds
    confusionMatrix = zeros(numel(Results.classes));
    
    goldStandard = Results.classGoldStandard{numRun};
    result = Results.classResult{numRun};
    
    for i = 1:numel(Results.classes)
        goldStandard(Results.classGoldStandard{numRun} == Results.classes(i)) = i;
        result(Results.classResult{numRun} == Results.classes(i)) = i;
    end
    
    for i = 1:size(goldStandard, 1)
        confusionMatrix(goldStandard(i), result(i)) = confusionMatrix(goldStandard(i), result(i)) + 1;
    end
    
    Results.confusionMatrices{numRun} = confusionMatrix;
    Results.confusionMatrix = Results.confusionMatrix + Results.confusionMatrices{numRun};
    
    % disp(['Confusion matrix for run ' num2str(numRun) ': ']);
    % disp(confusionMatrix);
end

if options.disp
    disp(['Confusion matrix complete: ']);
    disp(Results.confusionMatrix);
    
    if exist ('Results.regConstant', 'var') 
        disp(['Regularization constants: ']);
        disp(Results.regConstat);
    end
end

Results.confusionMatrixNorm = Results.confusionMatrix;
for i = 1:size(Results.confusionMatrix, 1)
    temp = sum(Results.confusionMatrix(i, :));
    if temp == 0
        temp = 1;
    end
    Results.confusionMatrixNorm(i, :) = Results.confusionMatrix(i, :) ./ temp;
end

if options.disp
    disp(['Confusion matrix complete (normed): ']);
    disp(Results.confusionMatrixNorm);
end

% -------------------------------------------------------------------------
% Calculate classwise averaged classification rate
Results.classificationRate = 0;
for i = 1:size(Results.confusionMatrix, 1)
    Results.classificationRate = Results.classificationRate + Results.confusionMatrixNorm(i, i);
end
Results.classificationRate = Results.classificationRate / size(Results.confusionMatrix, 1);
if options.disp
    disp(['Classification Rate: ' num2str(Results.classificationRate)]);
end

% -------------------------------------------------------------------------
% Calculate ROC curve
if options.roc ...
        && numel(Results.classes) == 2 ...
        && strcmp(Results.ClassifyOptions.classifier, 'SVM')
    discriminators = [];
    goldStandard = [];
    
    for numRun = 1:Results.numFolds
        discriminators = [discriminators; Results.discriminators{numRun}];
        goldStandard = [goldStandard; Results.classGoldStandard{numRun}];
    end
    
    stepSize = (max(discriminators) - min(discriminators)) / options.rocSamples;
    thresholdValues = min(discriminators):stepSize:max(discriminators);
    
    Results.rocCurve = zeros(2, numel(thresholdValues));
    
    classes = zeros(size(discriminators));
    for i = 1:numel(thresholdValues)
        classes(discriminators < thresholdValues(i)) = Results.classes(2);
        classes(discriminators >= thresholdValues(i)) = Results.classes(1);
        truePositives = sum((classes == Results.classes(2)) & (goldStandard == Results.classes(2)));
        trueNegatives = sum((classes == Results.classes(1)) & (goldStandard == Results.classes(1)));
        falsePositives = sum((classes == Results.classes(2)) & (goldStandard == Results.classes(1)));
        falseNegatives = sum((classes == Results.classes(1)) & (goldStandard == Results.classes(2)));
        
        Results.rocCurve(1,i) = truePositives / (truePositives + falseNegatives); % Sensitivit�t
        Results.rocCurve(2,i) = 1 - trueNegatives / (trueNegatives + falsePositives); % Specificity
    end
    
    Results.auRoc = 0;
    for i = 2:numel(thresholdValues)
        Results.auRoc = Results.auRoc + ((Results.rocCurve(1,i-1)) - (Results.rocCurve(1,i))) * (Results.rocCurve(2,i) + Results.rocCurve(2,i-1)) / 2;
    end
end

% -------------------------------------------------------------------------
% Create overall classification results (flatten cross validation)

Results.allGoldstandard = zeros(options.datasetSize, 1) - 1;
Results.allResult = zeros(options.datasetSize, 1) - 1;
Results.allDiscriminators = zeros(options.datasetSize, 1) - 10000;
Results.allCorrect = zeros(options.datasetSize, 1) - 1;
Results.allValid = zeros(options.datasetSize, 1) - 1;
Results.numSamplesClasses = zeros(1, numel(Results.classes));

for numRun = 1:Results.numFolds
    goldStandard = Results.classGoldStandard{numRun};
    result = Results.classResult{numRun};
    idx = Results.testIdx{numRun};
    if numel(Results.classes) == 2 ...
        && strcmp(Results.ClassifyOptions.classifier, 'SVM')
        disc = Results.discriminators{numRun};
    end
    
    Results.allGoldstandard(idx) = goldStandard;
    Results.allResult(idx) = result;
    Results.allCorrect(idx) = double(goldStandard == result);  
    if numel(Results.classes) == 2 ...
        && strcmp(Results.ClassifyOptions.classifier, 'SVM')
        Results.allDiscriminators(idx) = disc;
    end
end

for k = 1:numel(Results.classes)
    Results.numSamplesClasses(k) = sum(double(Results.allGoldstandard == Results.classes(k)));
end

Results.allValid = Results.allGoldstandard ~= -1;

% -------------------------------------------------------------------------
% End

if options.disp
    disp('-----------------------');
end